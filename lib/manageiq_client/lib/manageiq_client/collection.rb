module ManageIQClient
  class Collection
    extend BasicRequest

    basic_request :discover, uri: '?limit=0'
    basic_request :all, uri: ''

    def initialize(connection, definition)
      @connection = connection
      @base_path = URI.parse(definition['href']).path.gsub /\/\z/, ''
    end

    def find(*args)
      options = args.extract_options!
      id = args.first

      request options.merge uri: id
    end

    def discover_api()
      actions = discover
      return self unless actions.key? 'actions'

      actions['actions'].each do |action|
        action_path = URI.parse(action['href']).path.sub @base_path, ''
        action_method = action['method'].upcase
        action_name = action['name'].to_sym
        self.class.send :define_method, action_name do |*args|
          body = ''

          options = args.extract_options!
          uri = args.first

          unless %w(GET DELETE).include? action_method
            body = { action: action_name }
            if options[:body] && options[:body].is_a?(String)
              options[:body] = JSON(options[:body])
            elsif options[:body].nil?
              options[:body] = {}
            end

            body = body.merge(options[:body]).to_json
          end

          request(
            uri: [action_path, uri].compact.join('/'),
            expects: options[:expects] || [200],
            method: options[:method] || action_method,
            headers: options[:headers] || {},
            body: body,
            parse: true
          )
        end
      end

      self
    end

    private

    attr_reader :connection

    def request(options)
      options[:uri] = [@base_path, options[:uri]].compact.join('/').sub(/\/\z/, '')
      connection.request options
    end
  end
end
