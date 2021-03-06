class ExoFactsController < UIViewController
  include MapKit

  def viewDidLoad
    super
    view.styleId = 'ExoView'
    self.title = "Discover"

    @defaults = NSUserDefaults.standardUserDefaults
    @defaults["user_location"] = nil

    @all_regions = Location.all_regions

    if CLLocationManager.locationServicesEnabled

      if (CLLocationManager.authorizationStatus == KCLAuthorizationStatusAuthorized)
        @location_manager = set_location_manager

        if CLLocationManager.significantLocationChangeMonitoringAvailable
          @location_manager.startMonitoringSignificantLocationChanges
        else
          NSLog("Significant location change service not available.")
        end

        if CLLocationManager.regionMonitoringAvailable
          @all_regions.each do |region|
            @location_manager.startMonitoringForRegion(region, desiredAccuracy: 1.0)
          end

          @user_coords = @location_manager.location.coordinate
          @regionStateArray = []

          @locations = []
          @location_manager.monitoredRegions.each {|region| @locations << region}

          @regionStateArray << @locations.find do |region|
            calculateDistance(@user_coords, region.center) < 100
          end

          if @regionStateArray.first != nil

            @all_regions.each_with_index do |location, index|
              if location.containsCoordinate(@user_coords)
                @location_id = index + 1

                @defaults["user_location"] = @location_id

                populate_view_with_data

                @view_map_button = UIBarButtonItem.alloc.initWithTitle("Map", style: UIBarButtonItemStyleBordered, target:self, action:'createMap')
                self.navigationItem.rightBarButtonItem = @view_map_button

                @exo_back_button = UIBarButtonItem.alloc.initWithTitle("Facts", style: UIBarButtonItemStyleBordered, target:self, action:'back_to_facts')
                self.navigationItem.leftBarButtonItem = nil
              end
            end

          elsif @regionStateArray.first == nil
            @black_bar = UIView.alloc.initWithFrame(CGRectMake(0, 0, self.view.frame.size.width, 20))
            @black_bar.backgroundColor = UIColor.blackColor
            self.view.addSubview(@black_bar)

            closest_system_and_distance = find_closest_region
            @closest_system_index = closest_system_and_distance.keys.first
            @closest_region_distance = closest_system_and_distance[@closest_system_index]
            @closest_region_name = closest_system_and_distance[:location_name]

            closest_region_view

            @view_map_button = UIBarButtonItem.alloc.initWithTitle("Map", style: UIBarButtonItemStyleBordered, target:self, action:'createMap')
            self.navigationItem.rightBarButtonItem = @view_map_button

            @exo_facts_button = UIBarButtonItem.alloc.initWithTitle("System", style: UIBarButtonItemStyleBordered, target:self, action:'back_to_closest_region_view')
            self.navigationItem.leftBarButtonItem = nil


            self.view.bringSubviewToFront(@black_bar)
          end

          NSLog("Enabling region monitoring.")
        else
          NSLog("Warning: Region monitoring not supported on this device.")
        end
      else
        @location_manager = CLLocationManager.alloc.init
        @location_manager.startUpdatingLocation
        NSLog("Location services for this app not enabled")
        general_alert("Location services must be allowed for this application.")
      end
    else
      general_alert("Location services not enabled.")
      NSLog("Location services not enabled. FIX IT IN SETTINGS!")
    end

  end

  def initWithNibName(name, bundle: bundle)
    super
    @planet = UIImage.imageNamed('planet.png')
    @planetSel = UIImage.imageNamed('planet-select.png')
    self.tabBarItem = UITabBarItem.alloc.initWithTitle('Discover', image: @planet, tag: 1)
    self.tabBarItem.setFinishedSelectedImage(@planetSel, withFinishedUnselectedImage:@planet)
    self
  end

  def set_location_manager
    @location_manager = CLLocationManager.alloc.init
    @location_manager.desiredAccuracy = 1.0
    @location_manager.distanceFilter = 5
    @location_manager.delegate = self
    @location_manager.pausesLocationUpdatesAutomatically = false
    @location_manager.activityType = CLActivityTypeFitness
    @location_manager.startUpdatingLocation
  end

  def calculateDistance(coord1, coord2)
    earths_radius = 6371
    lat_diff = (coord2.latitude - coord1.latitude) * (Math::PI / 180)
    long_diff = (coord2.longitude - coord1.longitude) * (Math::PI / 180)
    lat1_in_radians = coord1.latitude * (Math::PI / 180)
    lat2_in_radians = coord2.latitude * (Math::PI / 180)
    nA = (Math.sin(lat_diff/2) ** 2 ) + Math.cos(lat1_in_radians) * Math.cos(lat2_in_radians) * ( Math.sin(long_diff/2) ** 2 )
    nC = 2 * Math.atan2( Math.sqrt(nA), Math.sqrt( 1 - nA ))
    nD = earths_radius * nC
    return nD * 1000
  end

  def populate_view_with_data
    System.pull_system_data(@location_id) do |system|

      @defaults["system_name"] = system[:name]
      @defaults["system_distance"] = system[:distance]
      @defaults["system_description"] = system[:description]

      @achievement_label = UILabel.alloc.initWithFrame(CGRectZero)
      @achievement_label.styleClass = 'h2'
      @achievement_label.text = "You are visiting"
      @achievement_label.sizeToFit
      @achievement_label.center = CGPointMake(self.view.frame.size.width / 2, 90)
      @achievement_label.styleClass = 'visit_achievement'
      self.view.addSubview(@achievement_label)

      @planetTitle = UILabel.alloc.initWithFrame(CGRectZero)
      @planetTitle.styleClass = 'h1'
      @planetTitle.text = system[:name]
      @planetTitle.sizeToFit
      @planetTitle.center = CGPointMake(self.view.frame.size.width / 2, 125)
      self.view.addSubview(@planetTitle)

      frame = UIScreen.mainScreen.applicationFrame
      origin = frame.origin
      size = frame.size
      body = UITextView.alloc.initWithFrame([[origin.x, origin.y + 100], [size.width, size.height]])
      body.styleClass = 'PlanetText'
      body.text = system[:description]
      body.backgroundColor = UIColor.clearColor
      body.editable = false

      scroll_view = UIScrollView.alloc.initWithFrame(frame)
      scroll_view.showsVerticalScrollIndicator = true
      scroll_view.scrollEnabled = true
      scroll_view.addSubview(body)
      scroll_view.backgroundColor = UIColor.clearColor
      scroll_view.contentSize = body.frame.size
      self.view.addSubview(scroll_view)
    end
  end

  def closest_region_view
    System.pull_system_data(@closest_system_index) do |system|

      @close_to_region_label = UILabel.alloc.initWithFrame(CGRectZero)
      @close_to_region_label.styleClass = 'h1'
      @close_to_region_label.text = "You're close!"
      @close_to_region_label.sizeToFit
      @close_to_region_label.center = CGPointMake(self.view.frame.size.width / 2, 90)
      self.view.addSubview(@close_to_region_label)

      frame = UIScreen.mainScreen.applicationFrame
      origin = frame.origin
      size = frame.size
      body = UITextView.alloc.initWithFrame([[origin.x, origin.y + 100], [size.width, size.height]])
      body.styleClass = 'PlanetText'
      body.text = "You are #{@closest_region_distance.round(2)} mi from #{system[:name]} at #{@closest_region_name}. Click on the map to find out where it is!"
      body.backgroundColor = UIColor.clearColor
      body.editable = false

      scroll_view = UIScrollView.alloc.initWithFrame(frame)
      scroll_view.showsVerticalScrollIndicator = true
      scroll_view.scrollEnabled = true
      scroll_view.addSubview(body)
      scroll_view.backgroundColor = UIColor.clearColor
      scroll_view.contentSize = body.frame.size
      self.view.addSubview(scroll_view)
    end
  end

  def back_to_closest_region_view
    @map.removeFromSuperview()
    self.navigationItem.leftBarButtonItem = nil
    self.navigationItem.rightBarButtonItem = @view_map_button
    closest_region_view
  end

  def back_to_facts
    @map.removeFromSuperview()
    self.navigationItem.leftBarButtonItem = nil
    self.navigationItem.rightBarButtonItem = @view_map_button
    populate_view_with_data
  end

  def createMap
    @map = MapView.new
    @map.frame = self.view.frame
    @map.delegate = self
    @map.region = CoordinateRegion.new([41.889911, -87.637657], [0.2, 0.2])
    @map.shows_user_location = true
    @map.zoom_enabled = true
    @map.scroll_enabled = true

    @all_regions.each do |region|
      place = MKPointAnnotation.new
      place.coordinate = region.center
      place.title = region.identifier
      @map.addAnnotation(place)
    end
    self.navigationItem.leftBarButtonItem = @exo_back_button
    self.navigationItem.rightBarButtonItem = nil
    view.addSubview(@map)
  end

  def find_closest_region
    distance_to_system = []
    @all_regions.each_with_index do |region, index|
      distance_to_system << calculateDistance(region.center, @user_coords)
    end

    system_distance = distance_to_system.min
    closest_system_index = distance_to_system.index(system_distance)
    closest_region = @all_regions[closest_system_index]
    closest_system_distance = system_distance / 1609.344

    {closest_system_index => closest_system_distance, location_name: closest_region.identifier}
  end

  def locationManager(manager, didUpdateLocations:locations)
    @latitude = locations.last.coordinate.latitude
    @longitude = locations.last.coordinate.longitude
  end

  def locationManager(manager, didFailWithError:error)
    show_error_message('Enable the Location Services for this app in Settings.')
  end

  def locationManager(manager, didEnterRegion:region)
  end

  def locationManager(manager, didExitRegion:region)
    @defaults["user_location"] = nil
  end

  def locationManager(manager, monitoringDidFailForRegion:region, withError:error)
    general_alert(error)
  end

  def show_error_message(message)
    general_alert(message)
  end

  def display_lat_long
    general_alert("Lat: #{@latitude}, Long: #{@longitude}")
  end

  def general_alert(message)
    alert = UIAlertView.new
    alert.addButtonWithTitle("OK")
    alert.message = "#{message}"
    alert.show
  end
end

