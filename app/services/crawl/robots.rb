module Crawl
  # robots.txt, as much of it as a polite crawler needs: which paths are ours to
  # fetch, how long to wait between requests, and where the sitemaps are.
  #
  # Longest-match-wins with Allow breaking ties, which is Google's rule rather
  # than the 1994 draft's first-match. The draft loses to how robots.txt is
  # actually written today — a broad Disallow with narrow Allow exceptions under
  # it is the common shape, and first-match reads it as "none of this".
  class Robots
    Group = Struct.new(:rules, :delay)
    Rule = Struct.new(:pattern, :allow)

    WILDCARD = "*".freeze

    def self.permissive = new({}, [])

    # `agent` is our own User-Agent token, matched against each group's
    # User-Agent line the way robots.txt intends: a case-insensitive prefix,
    # so `Archyve` catches a group naming `archyve-bot`.
    def self.parse(text, agent:)
      groups = Hash.new { |hash, key| hash[key] = Group.new([], nil) }
      sitemaps = []
      current = []
      naming_agents = false

      text.to_s.each_line do |line|
        field, value = split(line)
        next unless field

        case field
        when "user-agent"
          current = [] unless naming_agents
          naming_agents = true
          current << value.downcase
        when "sitemap"
          sitemaps << value
        else
          naming_agents = false
          current.each { |name| apply(groups[name], field, value) }
        end
      end

      new(groups, sitemaps, agent: agent)
    end

    def self.split(line)
      line = line.split("#", 2).first.to_s.strip
      return if line.empty?

      field, value = line.split(":", 2)
      return if value.nil?

      [field.strip.downcase, value.strip]
    end

    def self.apply(group, field, value)
      case field
      when "disallow" then group.rules << Rule.new(value, false) unless value.empty?
      when "allow" then group.rules << Rule.new(value, true) unless value.empty?
      when "crawl-delay" then group.delay = value.to_f if value.to_f.positive?
      end
    end

    attr_reader :sitemaps

    def initialize(groups, sitemaps, agent: nil)
      @groups = groups
      @sitemaps = sitemaps
      @agent = agent.to_s.downcase
    end

    def allowed?(path)
      match = applicable_rules
        .select { |rule| matches?(rule.pattern, path) }
        .max_by { |rule| [rule.pattern.length, rule.allow ? 1 : 0] }

      match.nil? || match.allow
    end

    def crawl_delay = group&.delay

    private

    attr_reader :groups, :agent

    # The group naming us, or the one naming everyone. An empty Disallow group
    # for `*` still counts: silence and "you may have everything" are the same
    # answer, and the distinction only matters if we ever refuse to crawl a site
    # with no robots.txt at all, which we don't.
    def group
      @group ||= groups[most_specific_agent]
    end

    def most_specific_agent
      groups.keys
        .reject { |name| name == WILDCARD }
        .select { |name| agent.start_with?(name) }
        .max_by(&:length) || WILDCARD
    end

    def applicable_rules = group&.rules || []

    def matches?(pattern, path)
      anchored = pattern.end_with?("$")
      pattern = pattern.delete_suffix("$") if anchored

      regex = pattern.split(WILDCARD, -1).map { |part| Regexp.escape(part) }.join(".*")
      path.match?(/\A#{regex}#{"\\z" if anchored}/)
    end
  end
end
