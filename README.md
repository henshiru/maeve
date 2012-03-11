Maeve installation guide
========================

Platforms
---------
Maeve is only available for Windows now.

Prerequisites
-------------

### Install Ruby 1.8
Download Ruby 1.8 (not 1.9) from  http://rubyinstaller.org

Check "Associate .rb and .rbw files with this Ruby installation" for convinience

### Install wxruby and ruby-opengl gems
Download prebuilt ruby-opengl from http://rubyforge.org/frs/?group_id=2103 (e.g. ruby-opengl-0.60.1-i386-mswin32.gem)

start->program->Ruby 1.8.x-xxxx->Start Command Prompt with Ruby

    gem install wxruby
    cd <your download directory>
    gem install ruby-opengl-0.60.1-i386-mswin32.gem
    
Launch
------

Doubleclick lib/main.rb
