**NOTICE**: I'm slowly migrating my repositories to my own Git server. Please visit this repository at [https://git.myzel394.app/Myzel394/zsh-copilot](https://git.myzel394.app/Myzel394/zsh-copilot) for the latest updates.

# zsh-copilot

Get suggestions **truly** in your shell. No `suggest` bullshit. Just press `CTRL + Z` and get your suggestion.

https://github.com/Myzel394/zsh-copilot/assets/50424412/ed2bc8ac-ce49-4012-ab73-53cf6f3151a2

## Installation

### Dependencies

Please make sure you have the following dependencies installed:

* [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
* [jq](https://github.com/jqlang/jq)
* [curl](https://github.com/curl/curl)

### Oh My Zsh

1. Clone `zsh-copilot` into `$ZSH_CUSTOM/plugins` (by default ~/.config/oh-my-zsh/custom/plugins)

```sh
git clone https://git.myzel394.app/Myzel394/zsh-copilot ${ZSH_CUSTOM:-~/.config/oh-my-zsh/custom}/plugins/zsh-copilot
```

2. Add `zsh-copilot` to the plugins array in your `.zshrc` file:

```bash
plugins=( 
    # your other plugins...
    zsh-autosuggestions
)
```

### Manual Installation

```sh
git clone https://git.myzel394.app/Myzel394/zsh-copilot ~/.config/zsh-copilot
echo "source ~/.config/zsh-copilot/zsh-copilot.plugin.zsh" >> ~/.zshrc
```

## Configuration

Set these variables in `.zshrc` **before** loading the plugin:

```sh
export ZSH_COPILOT_ENDPOINT="https://api.openai.com/v1/chat/completions"
export ZSH_COPILOT_MODEL="gpt-4o-mini"
export ZSH_COPILOT_API_KEY="your-api-key"
```

The endpoint must be the **full Chat Completions URL**, not just the server's
base URL. Any service exposing the OpenAI-compatible Chat Completions protocol
can be used with the same three settings:

| Service | `ZSH_COPILOT_ENDPOINT` | Example `ZSH_COPILOT_MODEL` |
| --- | --- | --- |
| OpenAI | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` |
| Gemini | `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` | `gemini-2.5-flash` |
| Ollama local | `http://localhost:11434/v1/chat/completions` | `llama3.2` |
| Grok (xAI) | `https://api.x.ai/v1/chat/completions` | `grok-3-mini` |

Choose a model available on your server/account. For Ollama, download the model
first (for example, `ollama pull llama3.2`) and leave `ZSH_COPILOT_API_KEY` unset
or empty for a local server without authentication.

Protocol references: [Gemini](https://ai.google.dev/gemini-api/docs/openai),
[Ollama](https://docs.ollama.com/api/openai-compatibility),
[xAI](https://docs.x.ai/docs/api-reference).

These settings replace `ZSH_COPILOT_AI_PROVIDER`, `OPENAI_API_URL`,
`ANTHROPIC_API_URL`, and the provider-specific key variables. Existing users
should migrate to the three settings above. Native Anthropic Messages endpoints
use a different protocol; use an OpenAI-compatible gateway for those models.

Other configuration options:

- `ZSH_COPILOT_KEY`: Key to press to get suggestions (default: ^z)
- `ZSH_COPILOT_SEND_CONTEXT`: If `true`, zsh-copilot will send context information to the AI model (default: true)
- `ZSH_COPILOT_DEBUG`: Enable private, per-request metadata logging (default: false)
- `ZSH_COPILOT_TIMEOUT`: Request timeout in seconds (default: 60)

To see all available configurations and their current values, run:

```sh
zsh-copilot
```

## Usage

Type in your command or your message and press `CTRL + Z` to get your suggestion!

Suggestions must start with `+` (completion) or `=` (replacement), contain a
nonempty body, and fit within 8192 characters including the prefix. Control
characters, including newlines, tabs and terminal escape sequences, are rejected.
A replacement is placed directly in the editable command buffer; review it and
press Enter to run it. Validation checks formatting, not command safety.

### Context and temporary files

Context sending remains enabled by default. Each request collects the username,
user/group IDs, current directory, shell, terminal type, `uname -a` and OS release
information. It does not collect shell history, project files, `PATH`, tool lists
or the full environment. Set `ZSH_COPILOT_SEND_CONTEXT=false` to omit machine
context; the input before the cursor is still sent.

The user message contains a JSON object with `input` and `context` fields. Context
is kept out of the system instructions and marked as untrusted data. This
separation does not guarantee protection against prompt injection.

Each request uses a private directory created by `mktemp -d` under `${TMPDIR:-/tmp}`.
On completion, failure or cancellation, the plugin stops its HTTP worker before
removing temporary files. Signal traps are scoped to the function.

HTTP failures display the status code and a bounded, sanitized provider error
message, with the configured API key redacted. Internal background jobs do not
print job IDs or completion notices into the prompt.

With debug enabled, only a small `debug.log` containing the timestamp, curl
exit code and HTTP status is retained in that directory, and its path is displayed in Zsh. The
directory has mode `700` and the log has mode `600`. Logs omit API keys, endpoint
URLs, input, context and responses. Remove retained debug directories when you
no longer need them; debug is off by default.

### API key storage

The plugin reads `ZSH_COPILOT_API_KEY` from the shell and does not persist it.
You can keep its assignment in a separate file, for example
`~/.config/zsh-copilot/credentials.zsh`, give that file mode `600`, and source it
from `.zshrc` before loading the plugin. Keep this file outside the repository.
This restricts file access; it is not encrypted secret storage.

## Development

Run offline request/response checks with real zsh and jq and a mocked HTTP client:

```sh
python3 -m unittest discover -s tests -v
```
