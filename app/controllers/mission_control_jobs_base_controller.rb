# Base controller for the mounted Mission Control - Jobs engine (see
# config/initializers/mission_control_jobs.rb). Admin-only, like Settings.
class MissionControlJobsBaseController < ApplicationController
  require_role :admin
end
