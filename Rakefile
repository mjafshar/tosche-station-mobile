# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require 'bubble-wrap'
require 'twittermotion'
require 'map-kit-wrapper'
require 'rubygems'
require 'motion-pixatefreestyle'

begin
  require 'bundler'
  Bundler.require
rescue LoadError
end

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'tosche-station-mobile'
  app.frameworks += ['Social', 'Twitter']
  app.pixatefreestyle.framework = 'vendor/PixateFreestyle.framework'
  app.interface_orientations = [:portrait]
end
