module RubyFPS::API
  class Base < RubyFPS::Model
    def submit
      begin
        url = RubyFPS.api_endpoint + '?' + RubyFPS.query_string(self.to_params)
        response = RestClient.get(url)
        self.class::Response.from_xml(response.body)
      rescue RestClient::BadRequest, RestClient::Unauthorized, RestClient::Forbidden => e
        RubyFPS::API::ErrorResponse.from_xml(e.response.body)
      end
    end

    def to_params
      params = self.to_hash.merge(
        'Action' => action_name,
        'AWSAccessKeyId' => RubyFPS.access_key,
        'Version' => RubyFPS::API_VERSION,
        'Timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      )

      params['SignatureVersion'] = 2
      params['SignatureMethod'] = 'HmacSHA256'
      params['Signature'] = RubyFPS.signature(RubyFPS.api_endpoint, params)

      params
    end

    class BaseResponse < RubyFPS::Model
      attr_accessor :request_id

      def self.from_xml(xml)
        hash = MultiXml.parse(xml)
        response_key = hash.keys.find{|k| k.match(/Response$/)}
        new(hash[response_key])
      end

      def initialize(hash)
        assign(hash['ResponseMetadata'])
        result_key = hash.keys.find{|k| k.match(/Result$/)}
        assign(hash[result_key]) if hash[result_key] # not all APIs have a result object
      end
    end

    protected

    def to_hash
      parameter_names.inject({}) do |hash, name|
        val  = send(name)
        hash.merge(name.camelcase => (val.respond_to? :to_hash) ? val.to_hash : val)
      end
    end

    def parameter_names
      (instance_variables - ['@mocha']).map{|iname| iname[1..-1]}
    end

    def action_name
      self.class.to_s.split('::').last
    end
  end
end
