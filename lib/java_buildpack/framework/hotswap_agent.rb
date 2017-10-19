# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'json'

module JavaBuildpack
  module Framework

    # Support hotswap agent (http://hotswapagent.org/)
    class HotswapAgent < JavaBuildpack::Component::BaseComponent

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'Hotswap Agent'
        #@uri = @configuration['uri']
        @appcontroller_uri = @configuration['appcontroller_uri']
        @jdblibs_uri = @configuration['jdblibs_uri']
        
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar('1.0', @configuration['uri'], hotswap_jar_name, libpath)
        download_jar('1.0', @configuration['vscodedebug_uri'], vscodedebug_jar_name, libpath)
        download_jar('1.0', @configuration['vscodedebug_ms_jar_uri'], vscodedebug_ms_jar_name, libpath)
        
        download_tar('1.0', @appcontroller_uri, true, libpath, 'App Controller')

        #download_tar('1.0', @jdblibs_uri, false, libpath, 'JDB')
      end

      def detect
        'true'
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('server.port','3000')
          .add_system_property('XXaltjvm','dcevm')
          .add_javaagent(libpath +  hotswap_jar_name)

        sources_dir = "/home/vcap/app/sources"
        
        #jdb_cmd = "/home/vcap/app/.java-buildpack/open_jdk_jre/bin/java -cp /home/vcap/app/.java-buildpack/open_jdk_jre/lib/tools.jar com.sun.tools.example.debug.tty.TTY"
        jdb_cmd = ('/home/vcap/app/.java-buildpack/open_jdk_jre/bin/java -cp /home/vcap/app/.java-buildpack/open_jdk_jre/lib/tools.jar:') + runtime_libpath + vscodedebug_jar_name + ":" + runtime_libpath + vscodedebug_ms_jar_name + (' sap.bentu.javadebug.VSCodeJavaDebuger ') + sources_dir
        devUtils = 
              {
                :start => "default",
                :server_port => ":$PORT",  
                :jdb_path => "#{jdb_cmd}", 
                :jdb_debug_path => "jdb", 
                :app_url => "http://localhost:3000" 
              }
        
 
        strDevUtils = devUtils.to_json.gsub "\"",  "\\\"" 
        @droplet.environment_variables.add_environment_variable 'DEV_UTILS',  "\"" + strDevUtils + "\""
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        enabled? #&& @droplet.environment_variables['HOT_SWAP_AGENT'] == 'true'
      end

 
      private

      def enabled?
        @configuration['enabled'].nil? || @configuration['enabled']
      end

      def libpath
        @droplet.sandbox + ('lib/')
      end

      def runtime_libpath
        "/home/vcap/app/.java-buildpack/hotswap_agent/lib/"
      end

      def hotswap_jar_name
        @configuration['hotswap_jar_name']
      end

      def vscodedebug_ms_jar_name
        @configuration['vscodedebug_ms_jar_name']
      end

      def vscodedebug_jar_name
        @configuration['vscodedebug_jar_name']
      end

      def binpath
        @droplet.sandbox + ('bin/')
      end

    end

  end
end
