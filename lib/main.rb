$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require 'rubygems'
require 'wx'
require 'kconv'
require 'app'

module Mv
  THE_APP = App.instance
end

Mv::App.instance.main_loop()
