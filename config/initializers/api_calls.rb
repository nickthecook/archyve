# Inserts ApiCalls::Recorder into RubyLLM's Faraday stack.
#
# By hand, because RubyLLM builds its connections directly and the gem exposes
# no middleware option — only :instrumenter, which carries a url and a status
# but no bodies, and :faraday_adapter, which is the wrong seam. The recorder is
# added after `super`, which leaves it innermost: it sees the serialized request
# body and the raw response, and sits inside the error middleware so a refusal
# is recorded before it is raised.
#
# RubyLLM caches each built connection for the life of the process, so this
# runs once per provider and stream mode rather than per call.
#
# Installed unconditionally rather than behind ARCHYVE_RECORD_API_CALLS. The
# recorder asks Setting.record_api_calls? per call and returns immediately when
# it is off, which is what lets recording be switched on against a running
# server instead of needing a restart.
module RubyLlmApiCallRecording
  def setup_middleware(faraday, settings)
    super
    faraday.use ApiCalls::Recorder, service_name: settings.provider.slug
  end
end

RubyLLM::Transport::Connection.singleton_class.prepend(RubyLlmApiCallRecording)
