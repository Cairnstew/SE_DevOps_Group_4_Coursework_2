{
  description = "Dev shell with Terraform, Google Cloud SDK, and AWS CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            terraform      # unfree
            google-cloud-sdk
            awscli2
          ];

          shellHook = ''
            mkdir -p $PWD/.aws

            export AWS_SHARED_CREDENTIALS_FILE=$PWD/.aws/credentials
            export AWS_CONFIG_FILE=$PWD/.aws/config

            if [ ! -f $PWD/.aws/credentials ]; then
              echo "⚠️  No credentials file found. Add your keys to .aws/credentials"
            fi
          '';
        };
      });
}
