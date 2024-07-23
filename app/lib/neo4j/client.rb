module Neo4j
  class Client
    def run(query, params = {})
      session { |s| s.run(query, params) }
    end

    def session(&)
      @session ||= driver.session(&)
    end

    private

    def driver
      puts "WEEEEEEEEEEEEEEEEEEEEEEEEEEE!"
      @driver ||= create_driver(url, 'neo4j', 'password')
    end

    def create_driver(uri, user, password)
      Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))
    end

    def url
      ENV.fetch('NEO4J_URL', 'neo4j://localhost:7687')
    end

    def username
      ENV.fetch('NEO4J_USERNAME', 'neo4j')
    end

    def password
      ENV.fetch('NEO4J_PASSWORD', 'password')
    end
  end
end
