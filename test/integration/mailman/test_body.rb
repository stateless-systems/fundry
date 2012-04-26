require_relative '../helper'
require 'mailman'

describe "Mailman Body" do
  before do
    @mailman = Mailman.new
    @body = @mailman.body "%strong this is a test!", { subject: "test email", unsubscribe: nil}
  end
  it "should generate html body given a haml template" do
    assert_match %r{<strong>this is a test!</strong>}, @body
  end
  it "should generate html title from subject" do
    assert_match %r{<title>test email</title>}, @body
  end
end
