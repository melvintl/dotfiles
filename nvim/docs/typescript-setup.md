# TypeScript LSP and Linting Setup

## Install Node.js and npm
If you don't have Node.js installed:
```bash
# Using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install --lts
nvm use --lts

# Or using apt on Debian/Ubuntu
# sudo apt install nodejs npm
```

## Install TypeScript Language Server
```bash
npm install -g typescript typescript-language-server
```

Note: `lua/custom/lsp.lua` enables this server under the name `ts_ls`
(nvim-lspconfig renamed it from `tsserver` in 2024).

## Install ESLint for linting
```bash
npm install -g eslint
```

The `eslint` entry in `lua/custom/lsp.lua` is the ESLint *language server*,
which is a separate package from the `eslint` CLI:
```bash
npm install -g vscode-langservers-extracted
```

## Install Prettier for formatting
```bash
npm install -g prettier
```

## Project-specific setup
For a TypeScript project, initialize ESLint:
```bash
npm init -y
npm install --save-dev eslint typescript-eslint prettier eslint-config-prettier eslint-plugin-prettier
```

ESLint 9+ uses the flat config format. Create an `eslint.config.js` file in
your project (the legacy `.eslintrc.*` files are no longer read by default):
```javascript
import tseslint from 'typescript-eslint';
import prettier from 'eslint-plugin-prettier/recommended';

export default tseslint.config(
  ...tseslint.configs.recommended,
  prettier,
  {
    rules: {
      // Custom rules
    },
  },
);
```

Create a `.prettierrc` file:
```json
{
  "semi": true,
  "trailingComma": "all",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2
}
```
