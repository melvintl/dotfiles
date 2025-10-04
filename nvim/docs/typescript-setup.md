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

Note: In Neovim's LSP configuration, this server is referred to as `tsserver`.

## Install ESLint for linting
```bash
npm install -g eslint
```

## Install Prettier for formatting
```bash
npm install -g prettier
```

## Project-specific setup
For a TypeScript project, initialize ESLint:
```bash
npm init -y
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin prettier eslint-config-prettier eslint-plugin-prettier
```

Create a `.eslintrc.js` file in your project:
```javascript
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
  },
  rules: {
    // Custom rules
  },
};
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
