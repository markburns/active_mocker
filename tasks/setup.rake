task :setup do
  unless ENV["TRAVIS"]
    Bundler.with_clean_env do
      rails_test_gemfile = File.expand_path(File.dirname(__FILE__)+ "/../test_rails_4_app/Gemfile")
      sh "BUNDLE_GEMFILE=#{rails_test_gemfile} bundle install --local 2>&1 >/dev/null" do |ok, res|
        sh "BUNDLE_GEMFILE=#{rails_test_gemfile} bundle install" unless ok
      end
    end
  end
end