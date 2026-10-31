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
- `ZSH_COPILOT_DEBUG`: Enable debug logging (default: false)
- `ZSH_COPILOT_TIMEOUT`: Request timeout in seconds (default: 60)

To see all available configurations and their current values, run:

```sh
zsh-copilot
```

## Usage

Type in your command or your message and press `CTRL + Z` to get your suggestion!

## Development

Run offline request/response checks with real zsh and jq and a mocked HTTP client:

```sh
python3 -m unittest discover -s tests -v
```
