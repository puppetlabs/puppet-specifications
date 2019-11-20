require 'spec_helper'
require 'json_schemer'
require 'net/http'

def read_schema_document(path)
  JSON.parse(File.open(path, 'rb') { |f| f.read })
end

def get_uri(url)
  redirects = 0
  begin
    response = Net::HTTP.get_response(URI.parse(url))
    url = response['location'] if response.is_a?(Net::HTTPRedirection)
    redirects += 1
  end while response.is_a?(Net::HTTPRedirection) && redirects < 10

  raise "Reached maximum redirects for #{url}" unless redirects < 10
  raise "Response from #{url} is not HTTP Status 200: #{response.message}" unless response.is_a?(Net::HTTPOK)
  response.body
end

def hyper_schema_for_schema(schema)
  hyper_schema_uri = schema['$schema']
  hyper_schema_content = JSON.parse(get_uri(hyper_schema_uri))
  JSONSchemer.schema(hyper_schema_content)
end

[
  { name: 'Tasks',  file: 'task.json'},
  { name: 'Errors', file: 'error.json'}
].each do |testcase|
  context "#{testcase[:name]} schema" do
    let(:schema_path) { File.join(PROJECT_ROOT, 'tasks', testcase[:file]) }
    let(:schema_json) { read_schema_document(schema_path) }
    let(:hyper_schema) { hyper_schema_for_schema(schema_json) }

    it 'is a valid JSON document' do
      expect { schema_json }.to_not raise_error
    end

    it 'is a valid JSON Schema document' do
      expect(hyper_schema.valid?(schema_json)).to be(true)
    end
  end
end

