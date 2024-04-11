package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

// TestTerraformAwsExample is a basic test example that just applies and destroys the Terraform code
func TestTerraformAwsExample(t *testing.T) {
    t.Parallel()

    // Define the Terraform options. Adjust your path to the Terraform code accordingly.
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        // The path to where your Terraform code is located
        TerraformDir: "../path/to/your/terraform/code",

        // Variables to pass to our Terraform code using -var options
        Vars: map[string]interface{}{
            "ami_id": "ami-123456", // Example variable. Replace with actual ones.
            // Define other variables as needed.
        },

        // Disable colors in Terraform commands so its easier to parse stdout/stderr
        NoColor: true,
    })

    // Ensure the Terraform destroy is called to clean up resources
    defer terraform.Destroy(t, terraformOptions)

    // Initialize and apply the Terraform code
    terraform.InitAndApply(t, terraformOptions)

    // Run terraform output to get the value of an output variable
    instanceType := terraform.Output(t, terraformOptions, "instance_type")
    // Replace "instance_type" with the actual output variable that outputs the instance type

    // Verify we're getting back the outputs we expect
    // Adjust the expected value accordingly
    assert.Equal(t, "t2.micro", instanceType)
}
