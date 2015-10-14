require 'spec_helper'

describe BioElastic do
  let(:options) { {} }

  describe BioElastic::Client do
    let(:client) { BioElastic::Client.new(options) }
    #let(:es_client) { instance_double(Elasticsearch::Client) } # can't get a verifying double to work
    let(:es_client) { double(Elasticsearch::Client, :create => :success) }
    let(:default_host) { "localhost" }
    let(:default_port) { "8200" }
    let(:host) { default_host }
    let(:port) { default_port }
    let(:log) { false }

    def clear_environment
      allow(ENV).to receive(:[]).with("ELASTIC_SEARCH_HOST").and_return(nil)
      allow(ENV).to receive(:[]).with("ELASTIC_SEARCH_PORT").and_return(nil)
    end

    before(:each) { allow(Elasticsearch::Client).to receive(:new).with(:hosts => {:port => port, :host => host}, :log => log).and_return(es_client) }

    describe "#initialize" do
      before(:each) { clear_environment }

      context "with no host passed in options" do
        context "and ELASTIC_SEARCH_HOST not set" do
          specify { expect(client.host).to eq(default_host) }
        end

        context "and ELASTIC_SEARCH_HOST set" do
          let(:host) { "some.elastic.host" }
          before(:each) { allow(ENV).to receive(:[]).with("ELASTIC_SEARCH_HOST").and_return(host) }

          specify { expect(client.host).to eq(host) }
        end
      end

      context "with host passed in options" do
        let(:host) { "some.other.elastic.host" }
        let(:options) { {:host => host} }

        specify { expect(client.host).to eq(host) }
      end

      context "with no port passed in options" do
        context "and ELASTIC_SEARCH_PORT not set" do
          specify { expect(client.port).to eq(default_port) }
        end

        context "and ELASTIC_SEARCH_PORT set" do
          let(:port) { "9200" }
          before(:each) { allow(ENV).to receive(:[]).with("ELASTIC_SEARCH_PORT").and_return(port) }

          specify { expect(client.port).to eq(port) }
        end
      end

      context "with port passed in options" do
        let(:port) { "9201" }
        let(:options) { {:port => port} }

        specify { expect(client.port).to eq(port) }
      end

      context "with no log option passed in options" do
        specify { expect(client.log).to be false }
      end

      context "with log option passed in options" do
        let(:log) { true }
        let(:options) { {:log => log} }

        specify { expect(client.log).to be log }
      end

      context "with no index_prefix passed in options" do
        specify { expect(client.index_prefix).to eq("ops-") }
      end

      context "with index_prefix passed in options" do
        let(:prefix) { "myops-" }
        let(:options) { {:index_prefix => prefix} }

        specify { expect(client.index_prefix).to eq(prefix) }
      end

      specify { expect(client.connection).to eq(es_client) }
    end

    describe "#index" do
      let(:options) { {:index_prefix => "opsy-" } }
      let(:timestamp) { Time.now.utc.strftime("%Y.%m.%d") }

      specify { expect(client.index).to eq("opsy-#{timestamp}") }
    end

    describe "#create_doc" do
      let(:params) { {:some => "hash"} }

      it "should send create msg to connection" do
        #expect(es_client).to receive(:create).with(params) { :success } # Getting the Elasticsearch::Client class does not implement the instance method: create
        expect(client.create_doc(params)).to eq(:success)
      end
    end
  end

  describe BioElastic::Document do
    let(:doc) { BioElastic::Document.new(options) }
    let(:client) { instance_double(BioElastic::Client) }
    let(:index) { "ops-2015-10-11" }

    before(:each) do
      allow(client).to receive(:index) { index }
    end

    describe "#initialize" do
      let(:now_time) { instance_double(Time) }
      let(:utc_time) { instance_double(Time) }
      let(:iso_time) { "2015-10-12T20:03:20Z" }
      
      before(:each) do
        allow(Time).to receive(:now).and_return(now_time)
        allow(now_time).to receive(:utc).and_return(utc_time)
        allow(utc_time).to receive(:iso8601).and_return(iso_time)
        allow(BioElastic::Client).to receive(:new).and_return(client)
      end
      
      specify { expect(doc.type).to eq("document") }
      specify { expect(doc.client).to eq(client) }
      specify { expect(doc.tags).to eq([]) }
      specify { expect(doc.host).to be_a_kind_of(String) }
      specify { expect(doc.timestamp).to eq(iso_time) }
      specify { expect(doc.version).to eq(1) }
      specify { expect(doc.body.keys).to include(:type, :tags, :host, :@timestamp, :@version) }
      
      context "with client option passed" do
        let(:options) { {:client => client} }

        specify { expect(doc.client).to eq(options[:client]) }
      end

      context "with tags option passed" do
        let(:options) { {:tags => ["tag1", "tag2"]} }

        specify { expect(doc.tags).to eq(options[:tags]) }
      end

      context "with host option passed" do
        let(:options) { {:host => "test.host"} }
        specify { expect(doc.host).to eq(options[:host]) }
      end

      context "with timestamp option passed" do
        let(:iso_time_opt) { "2015-10-11T10:03:20Z" }
        let(:options) { {:timestamp => iso_time_opt} }

        specify { expect(doc.timestamp).to eq(iso_time_opt) }
      end

      context "with version option passed" do
        let(:options) { {:version => 2} }

        specify { expect(doc.version).to eq(2) }
      end
    end

    describe "#is_valid?" do
      specify { expect(doc.is_valid?).to be true}

      context "with all valid options" do
        let(:valid_options) { {
          :tags      => ["tag1", "tag2"], 
          :host      => "some_host",
          :timestamp => "2015-10-11T10:03:20Z",
          :version   => 2
          } 
        }
        let(:options) { valid_options }

        specify { expect(doc.is_valid?).to be true}

        context "except client" do
          let(:options) { valid_options.merge(:client => "bad client") }

          specify { expect(doc.is_valid?).to be false}
        end

        context "except tags" do
          let(:options) { valid_options.merge(:tags => "bad_tags") }

          specify { expect(doc.is_valid?).to be false}
        end

        context "except host" do
          before(:each) { doc.host = [:not_goood_hostname] }

          specify { expect(doc.is_valid?).to be false}
        end

        context "except timestamp" do
          before(:each) { doc.timestamp = "2015-10-12 13:45:24 -0700" } #not utc.iso8601

          specify { expect(doc.is_valid?).to be false}
        end

        context "except version" do
          let(:options) { valid_options.merge(:version => "4") }

          specify { expect(doc.is_valid?).to be false}
        end
      end
    end

    describe "#create" do
      before(:each) { allow(doc).to receive(:client).and_return client }

      context "when document is valid" do
        before(:each) { allow(doc).to receive(:is_valid?).and_return true }

        it "should successfully create document" do
          expect(client).to receive(:create_doc).with(:index => index, :type => doc.type, :body => doc.body) { :success }
          expect(doc.create).to eq(:success)
        end
      end

      context "when document is not valid" do
        before(:each) { allow(doc).to receive(:is_valid?).and_return false }

        it "should raise an exception" do
          expect {doc.create}.to raise_error("document is not valid")
        end
      end
    end
  end

  describe BioElastic::OrderProcessing do
    let(:order_doc) { BioElastic::OrderProcessing.new(options) }

    describe "#initialize" do
      specify { expect(order_doc.type).to eq("order_processing") }

      context "with order_file_path option passed as string full path" do
        let(:options) { {:order_file_path => "/path/to/some_filename.csv" } }

        specify { expect(order_doc.order_filename).to eq(File.basename(options[:order_file_path])) }
        specify { expect(order_doc.order_file_path).to eq(options[:order_file_path]) }
        specify { expect(order_doc.body.keys).to include(
          :order_file_path, 
          :order_filename, 
          :records_imported, 
          :records_rejected, 
          :total_records
          ) 
        }
      end
    end

    describe "#is_valid?" do
      let(:valid_options) { {
        :order_file_path => "/path/to/some_filename.csv", 
        :records_imported => 5,
        :records_rejected => 5,
        :total_records    => 10
        } 
      }

      context "with all mandatory data passed and valid" do
        let(:options) { valid_options}

        specify { expect(order_doc.is_valid?).to be true }
      end

      context "with all valid options except order_file_path option" do
        let(:options) { valid_options.merge(:order_file_path => "some_filename.csv") }

        specify { expect(order_doc.is_valid?).to be false }
      end

      context "with all valid options except records_imported" do
        let(:options) { valid_options.merge(:records_imported => "5") }

        specify { expect(order_doc.is_valid?).to be false }
      end

      context "with all valid options except records_rejected" do
        let(:options) { valid_options.merge(:records_rejected => "5") }

        specify { expect(order_doc.is_valid?).to be false }
      end

      context "with all valid options except total_records" do
        let(:options) { valid_options.merge(:total_records => "5") }

        specify { expect(order_doc.is_valid?).to be false }
      end

      context "with no options passed" do
        specify { expect(order_doc.is_valid?).to be false }
      end
    end
  end
end