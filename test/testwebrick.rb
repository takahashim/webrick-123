#!/usr/local/bin/ruby

require 'runit/testcase'
require 'runit/cui/testrunner'

$:.unshift("../lib")

module TestWEBrick
  def handleTests(klass)
    testrunner = RUNIT::CUI::TestRunner.new
    if ARGV.size == 0
      suite = klass.suite
    else
      suite = RUNIT::TestSuite.new
      ARGV.each do |testmethod|
        suite.add_test(klass.new(testmethod))
      end
    end
    testrunner.run(suite)
  end
  module_function :handleTests

  def start
    runner = RUNIT::CUI::TestRunner.new
    Dir["Test*.rb"].sort.each{ |file|
      require file
      class_name = file.sub(/\.rb$/, '')
      klass = eval(class_name)
      RUNIT::CUI::TestRunner.quiet_mode = true
      $stderr.print klass, ": "
      runner.run(klass.suite)
    }
  end
  module_function :start

  def removedirs(dir)
    Dir::open(dir){|d|
      d.each{|name|
        next if name == "."
        next if name == ".."
        path = dir + "/" +  name
        File::chmod(0700, path)
        if File::directory?(path)
          removedirs(path)
        else
          File::unlink(path)
        end
      }
    }
    Dir::rmdir(dir)
  end
  module_function :removedirs

end

TestWEBrick::start if __FILE__ == $0
