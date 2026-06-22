module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: "module",
  },
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  rules: {
    quotes: ["warn", "double", {allowTemplateLiterals: true}],
    "@typescript-eslint/no-explicit-any": "off",
  },
  ignorePatterns: [
    "/lib/**/*",
    ".eslintrc.js",
  ],
};
