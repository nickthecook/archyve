# Gate the jobs dashboard with our own admin role check instead of HTTP basic
# auth — see MissionControlJobsBaseController.
MissionControl::Jobs.http_basic_auth_enabled = false
MissionControl::Jobs.base_controller_class = "MissionControlJobsBaseController"
