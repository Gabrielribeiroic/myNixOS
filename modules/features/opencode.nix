{ self, ... }:
{
  flake.nixosModules.opencode =
    { config, lib, pkgs, ... }:
    {
      options.features.opencode = {
        enable = lib.mkEnableOption "OpenCode AI coding agent and ComfyUI MCP runtime" // {
          default = false;
        };
      };

      config = lib.mkIf config.features.opencode.enable (
        let
            python = pkgs.python313;
            pythonPackages = python.pkgs;

            mcpTypes = pythonPackages.buildPythonPackage {
              pname = "mcp-types";
              version = "2.0.0";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/f5/4c/c78d78c3d52b0ac594ad7cc8ef5972adfe070e3597a8a4c6ce0cd39196ea/mcp_types-2.0.0-py3-none-any.whl";
                hash = "sha256-ay3nl8onl/Vot5Up4bJZSONN5RG8wL2C/vEDmm0bjrA=";
              };
              dependencies = with pythonPackages; [
                pydantic
                typing-extensions
              ];
            };

            mcp = pythonPackages.buildPythonPackage {
              pname = "mcp";
              version = "2.0.0";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/67/72/7d7897418912c1d12e87556630dfb7bf0eac71160e9bef8b447960804ee3/mcp-2.0.0-py3-none-any.whl";
                hash = "sha256-HLTHXS0se4wddWNV5dgqOfKCLMfxPiKiBR18o1kjSdY=";
              };
              dependencies = with pythonPackages; [
                anyio
                cryptography
                httpx2
                jsonschema
                mcpTypes
                opentelemetry-api
                pydantic
                pyjwt
                python-multipart
                sse-starlette
                starlette
                typing-extensions
                typing-inspection
                uvicorn
              ];
            };

            comfyCli = pythonPackages.buildPythonApplication {
              pname = "comfy-cli";
              version = "1.14.0";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/76/95/7acdfd0b54a5c52cbc301b706eb8c1f71d6e19b7e69247657988bf8def2b/comfy_cli-1.14.0-py3-none-any.whl";
                hash = "sha256-uhdaPlQpC3d5FTYRWip9vhqqLgWvVxcpPAG9+nNcklA=";
              };
              dependencies = with pythonPackages; [
                charset-normalizer
                cookiecutter
                gitpython
                httpx
                mixpanel
                packaging
                pathspec
                posthog
                psutil
                pyyaml
                questionary
                requests
                rich
                ruff
                semver
                tomlkit
                typer
                typing-extensions
                uv
                websocket-client
              ];
              # comfy-cli 1.14.0 declares mixpanel<5, while this locked
              # nixpkgs revision provides mixpanel 5.0.0.  The CLI's import
              # check and version/which/env checks exercise the relaxed pair.
              pythonRelaxDeps = [ "mixpanel" ];
              pythonImportsCheck = [ "comfy_cli" ];
            };

            comfyMcp = pythonPackages.buildPythonApplication {
              pname = "comfy-mcp";
              version = "0.10.0";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/b7/ba/b6adfb517983a5eed2d86b7b4e8199dc42aa2b028ef7d8b05f61f721195f/comfy_mcp-0.10.0-py3-none-any.whl";
                hash = "sha256-I/XgKphlpU2FgR6aQkK+ypEUAOCDo8je2+uwcwm67LA=";
              };
              dependencies = with pythonPackages; [
                anyio
                mcp
                pydantic
              ];
            };

            coderComfyPermissions = {
              "comfy-mcp_*" = "deny";
              "comfy-mcp_server_info" = "allow";
              "comfy-mcp_auth_status" = "allow";
              "comfy-mcp_system_stats" = "allow";
              "comfy-mcp_free_memory" = "allow";
              "comfy-mcp_fetch_outputs" = "allow";
              "comfy-mcp_get_logs" = "allow";
              "comfy-mcp_discover" = "allow";
              "comfy-mcp_which" = "allow";
              "comfy-mcp_project" = "allow";
              "comfy-mcp_nodes" = "allow";
              "comfy-mcp_node_dependencies" = "allow";
              "comfy-mcp_workflow_deps" = "allow";
              "comfy-mcp_search_templates" = "allow";
              "comfy-mcp_get_template" = "allow";
              "comfy-mcp_search_models" = "allow";
              "comfy-mcp_validate_workflow" = "allow";
              "comfy-mcp_list_workflow_slots" = "allow";
              "comfy-mcp_list_workflow_notes" = "allow";
              "comfy-mcp_auth_login" = "deny";
              "comfy-mcp_run_workflow" = "deny";
              "comfy-mcp_generate_image" = "deny";
              "comfy-mcp_partner_generate" = "deny";
              "comfy-mcp_emit_partner_workflow" = "deny";
              "comfy-mcp_run_template" = "deny";
              "comfy-mcp_job" = "deny";
              "comfy-mcp_launch_comfyui" = "deny";
              "comfy-mcp_stop_comfyui" = "deny";
              "comfy-mcp_restart_comfyui" = "deny";
              "comfy-mcp_update_comfyui" = "deny";
              "comfy-mcp_switch_comfyui_version" = "deny";
              "comfy-mcp_install_node" = "deny";
              "comfy-mcp_fetch_template" = "deny";
              "comfy-mcp_download_model" = "deny";
              "comfy-mcp_download" = "deny";
              "comfy-mcp_upload_file" = "deny";
              "comfy-mcp_set_workflow_slot" = "deny";
              "comfy-mcp_vary_workflow" = "deny";
            };

          in
          {
            environment.systemPackages = [ comfyCli comfyMcp ];
            # Make GUI-launched and shell-launched processes agree after the
            # next login; Syncthing continues to own the shared config dir.
            environment.sessionVariables.OPENCODE_CONFIG = "/etc/opencode-devbox.jsonc";

            environment.etc."opencode-devbox.jsonc".text = builtins.toJSON {
              "$schema" = "https://opencode.ai/config.json";
              permission = {
                "comfy-mcp_*" = "deny";
              };
              mcp."comfy-mcp" = {
                type = "local";
                command = [ "/run/current-system/sw/bin/comfy-mcp" ];
                environment = {
                  COMFYUI_URL = "http://100.106.27.67:8188";
                  COMFY_BIN = "/run/current-system/sw/bin/comfy";
                };
                enabled = true;
                timeout = 30000;
              };
              agent.coder.permission = coderComfyPermissions;
            };

            # Syncthing still owns ~/.config/opencode.  Point the normal
            # command at the generated devbox-only config without changing
            # the shared project config.
            home-manager.users.zep = { pkgs, ... }: {
              home.packages = [ pkgs.opencode ];
              home.sessionVariables.OPENCODE_CONFIG = "/etc/opencode-devbox.jsonc";
            };
          }
      );
    };
}
