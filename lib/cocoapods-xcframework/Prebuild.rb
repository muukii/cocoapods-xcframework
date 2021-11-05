require_relative "rome/build_framework"
require_relative "helper/passer"
require_relative "helper/target_checker"

# patch prebuild ability
module Pod
  class Installer
    private
   
    # @return [Analyzer::SpecsState]
    def prebuild_pods_changes
      return nil if local_manifest.nil?
      if @prebuild_pods_changes.nil?
        changes = local_manifest.detect_changes_with_podfile(podfile)
        @prebuild_pods_changes = Analyzer::SpecsState.new(changes)
        # save the chagnes info for later stage
        Pod::Prebuild::Passer.prebuild_pods_changes = @prebuild_pods_changes
      end
      @prebuild_pods_changes
    end

    public

    # Build the needed framework files
    def prebuild_frameworks!

      # build options
      sandbox_path = sandbox.root

      targets = []
     
      targets = self.pod_targets

      # targets = targets.reject { |pod_target| sandbox.local?(pod_target.pod_name) }

      # build!
      Pod::UI.puts "Prebuild frameworks (total #{targets.count})"
      # Pod::Prebuild.remove_build_dir(sandbox_path)
      targets.each do |target|
        if !target.should_build?
          UI.puts "Prebuilding #{target.label}"
          next
        end

        output_path = Pathname.new(sandbox.standard_sanbox_path).realpath + target.name
        
        output_path.mkpath unless output_path.exist?

        Pod::Prebuild.build_xcframework(
          sandbox_root_path: sandbox_path,
          target: target,
          output_path: output_path,
        )

        # save the resource paths for later installing

        if target.static_framework? and !target.resource_paths.empty?
          framework_path = output_path + target.framework_name
          standard_sandbox_path = sandbox.standard_sanbox_path

          resources = begin
              if Pod::VERSION.start_with? "1.5"
                target.resource_paths
              else
                # resource_paths is Hash{String=>Array<String>} on 1.6 and above
                # (use AFNetworking to generate a demo data)
                # https://github.com/leavez/cocoapods-binary/issues/50
                target.resource_paths.values.flatten
              end
            end
          raise "Wrong type: #{resources}" unless resources.kind_of? Array

          path_objects = resources.map do |path|
            object = Pod::Prebuild::Passer::ResourcePath.new
            object.real_file_path = framework_path + File.basename(path)
            object.target_file_path = path.gsub("${PODS_ROOT}", standard_sandbox_path.to_s) if path.start_with? "${PODS_ROOT}"
            object.target_file_path = path.gsub("${PODS_CONFIGURATION_BUILD_DIR}", standard_sandbox_path.to_s) if path.start_with? "${PODS_CONFIGURATION_BUILD_DIR}"
            object
          end
          Pod::Prebuild::Passer.resources_to_copy_for_static_framework[target.name] = path_objects
        end
      end
     
      instance_eval do
        path = sandbox.root + "Manifest.lock.tmp"
        path.rmtree if path.exist?
      end
    end

    # patch the post install hook
    old_method2 = instance_method(:run_plugins_post_install_hooks)
    define_method(:run_plugins_post_install_hooks) do
      old_method2.bind(self).()
      if Pod::is_prebuild_stage
        self.prebuild_frameworks!
      end
    end
  end
end
