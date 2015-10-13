require "bio_elastic/version"
require "elasticsearch"

module BioElastic
  class Client
    attr_reader :host, :port, :connection, :index_prefix
    
    def initialize(options={})
      @host = options[:host] || ENV["ELASTIC_SEARCH_HOST"] || "localhost"
      @port = options[:port] || ENV["ELASTIC_SEARCH_PORT"] || "8200"
      @index_prefix = options[:index_prefix] || "ops-"
      @connection   = Elasticsearch::Client.new :hosts => {:port => @port, :host => @host}, :log => true
    end

    def index
      "#{@index_prefix}#{Time.now.utc.strftime("%Y.%m.%d")}"
    end

    def create_doc(params)
      connection.create params
    end
  end

  class Document
    attr_accessor :tags, :host, :timestamp, :version
    attr_reader :type, :body, :client

    def initialize(options={})
      @type      = "document"
      @client    = options[:client] || BioElastic::Client.new
      @tags      = options[:tags] || []
      @host      = options[:host] || `hostname`.chomp
      @timestamp = options[:timestamp].nil? ? Time.now.utc.iso8601 : Time.parse(options[:timestamp]).utc.iso8601
      @version   = options[:version] || 1
      @body      = {:type => @type, :tags => @tags, :host => @host, :@timestamp => @timestamp, :@version => @version}
    end

    def is_valid?
      type.kind_of?(String) &&
      type == type.downcase &&
      client.kind_of?(BioElastic::Client) &&
      tags.kind_of?(Array) &&
      host.kind_of?(String) &&
      Time.parse(timestamp).utc.iso8601 == timestamp &&
      version.kind_of?(Integer) &&
      body.kind_of?(Hash)
    end

    def create
      raise("document is not valid") if !is_valid?
      client.create_doc(:index => client.index, :type => type, :body => body)
    end
  end

  class OrderProcessing < Document
    attr_accessor :order_file_path, :records_imported, :records_rejected, :total_records
    attr_reader :order_filename
    
    def initialize(options={})
      super

      @type = "order_processing"
      @order_file_path  = options[:order_file_path]
      @order_filename   = @order_file_path.nil? ? nil : File.basename(@order_file_path)
      @records_imported = options[:records_imported]
      @records_rejected = options[:records_rejected]
      @total_records    = options[:total_records]
      @body.merge!(
        :type             => @type, 
        :order_file_path  => @order_file_path, 
        :order_filename   => @order_filename,
        :records_imported => @records_imported,
        :records_rejected => @records_rejected,
        :total_records    => @total_records
      )
    end

    def is_valid?
      super &&
      !order_file_path.nil? &&
      !order_file_path.match(/^\/.+$/).nil? &&
      order_filename.kind_of?(String) &&
      records_imported.kind_of?(Integer) &&
      records_rejected.kind_of?(Integer) &&
      total_records.kind_of?(Integer)
    end
  end
end
