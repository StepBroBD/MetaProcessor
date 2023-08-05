{
  inputs = {
    nixpkgs.url = "flake:nixpkgs/nixpkgs-unstable";
    utils.url = "flake:flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , utils
    , ...
    }: utils.lib.eachDefaultSystem
      (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        lib = pkgs.lib;
        stdenv = if pkgs.stdenv.isLinux then pkgs.stdenv else pkgs.clangStdenv;

        python3 = pkgs.python3;
        python3Env = python3.withPackages (ps: with ps; [
          boto3
          click
          click-aliases
          click-option-group
          numpy
          pandas
          pyarrow
          rich
          scipy
          toml
          tqdm
        ] ++ lib.optionals stdenv.isLinux (with ps; [
          metawear
        ]));

        metaprocessor = python3.pkgs.buildPythonPackage rec {
          pname = "metaprocessor";
          inherit ((lib.importTOML ./pyproject.toml).project) version;

          format = "pyproject";
          disabled = python3.pkgs.pythonOlder "3";

          enableParallelBuilding = true;
          src = lib.cleanSource ./.;
          propagatedBuildInputs = [ python3Env ];
        };
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        packages.default = metaprocessor;

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.ruff ];
          buildInputs = [ python3Env python3.pkgs.venvShellHook ];
          venvDir = ".venv";
          postVenvCreation = ''
            pip install --upgrade pip setuptools wheel
            pip install --editable .
          '';
        };
      }
      ) // {
      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) metaprocessor;
      };
    };
}
