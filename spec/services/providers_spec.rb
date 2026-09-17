require "rails_helper"

RSpec.describe Providers do
  it "tipa os erros para que jobs decidam retry pela classe" do
    expect(described_class::TransientError).to be < described_class::Error
    expect(described_class::PermanentError).to be < described_class::Error
    expect(described_class::Error).to be < StandardError
  end

  it "mantém transitório e permanente como ramos distintos" do
    expect(described_class::TransientError).not_to be < described_class::PermanentError
    expect(described_class::PermanentError).not_to be < described_class::TransientError
  end
end
