require_relative "rome/build_framework"
require_relative "helper/target_checker"

# patch prebuild ability
module Pod
  class Installer
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
