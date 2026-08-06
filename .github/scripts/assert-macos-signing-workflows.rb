#!/usr/bin/env ruby
# frozen_string_literal: true

require "psych"

def fail_contract(message)
  warn "assert-macos-signing-workflows: #{message}"
  exit 1
end

def mapping_value(node, key)
  return nil unless node.is_a?(Psych::Nodes::Mapping)

  node.children.each_slice(2) do |candidate, value|
    return value if candidate.is_a?(Psych::Nodes::Scalar) && candidate.value == key
  end
  nil
end

def mapping_keys(node)
  return [] unless node.is_a?(Psych::Nodes::Mapping)

  node.children.each_slice(2).map do |key, _value|
    key.is_a?(Psych::Nodes::Scalar) ? key.value : nil
  end
end

def scalar_value(node)
  node.is_a?(Psych::Nodes::Scalar) ? node.value : nil
end

workflow_path = ARGV.fetch(0) { fail_contract("workflow path is required") }
root = Psych.parse_file(workflow_path)&.root
fail_contract("workflow root is not a mapping") unless root.is_a?(Psych::Nodes::Mapping)

triggers = mapping_value(root, "on")
fail_contract("workflow has no on mapping") unless triggers.is_a?(Psych::Nodes::Mapping)
unless mapping_keys(triggers) == ["workflow_dispatch"]
  fail_contract("release workflow must be workflow_dispatch-only")
end

jobs = mapping_value(root, "jobs")
package_job = mapping_value(jobs, "package-mac")
fail_contract("package-mac job is missing") unless package_job.is_a?(Psych::Nodes::Mapping)
unless scalar_value(mapping_value(package_job, "environment")) == "production-signing"
  fail_contract("package-mac is not attached to production-signing")
end

steps = mapping_value(package_job, "steps")
fail_contract("package-mac steps are missing") unless steps.is_a?(Psych::Nodes::Sequence)
step_named = lambda do |name|
  steps.children.find do |step|
    scalar_value(mapping_value(step, "name")) == name
  end
end

checkout = step_named.call("Check out private Nonet source")
fail_contract("production source checkout is missing") unless checkout
unless scalar_value(mapping_value(checkout, "uses")) == "actions/checkout@v6"
  fail_contract("production source checkout uses an unexpected action")
end
checkout_with = mapping_value(checkout, "with")
expected_checkout = {
  "repository" => "moonaries90/nonet",
  "ref" => "${{ inputs.source_ref }}",
  "ssh-key" => "${{ secrets.MATRIX_CO_SOURCE_DEPLOY_KEY }}",
  "persist-credentials" => "false",
  "fetch-depth" => "0"
}
expected_checkout.each do |key, expected|
  actual = scalar_value(mapping_value(checkout_with, key))
  fail_contract("production source checkout has unexpected #{key}") unless actual == expected
end

provenance = step_named.call("Verify provenance and import stable macOS signing identity")
fail_contract("production provenance step is missing") unless provenance
provenance_env = mapping_value(provenance, "env")
unless scalar_value(mapping_value(provenance_env, "REQUESTED_SOURCE_SHA")) == "${{ inputs.source_ref }}"
  fail_contract("production provenance is not bound to the dispatch SHA")
end
if mapping_keys(provenance_env).include?("NONET_MACOS_SIGNING_APPROVED_SOURCE_SHA")
  fail_contract("production provenance still uses a manually maintained SHA pin")
end

run_lines = scalar_value(mapping_value(provenance, "run"))&.lines&.map(&:strip)&.reject(&:empty?)
expected_run = [
  "set -euo pipefail",
  "bash release-automation/.github/scripts/production-macos-signing.sh setup"
]
unless run_lines == expected_run
  fail_contract("production provenance step does not exclusively call centralized setup")
end
