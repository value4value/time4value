module.exports = {
    printWidth: 120,
    tabWidth: 4,
    useTabs: false,
    semi: true,
    singleQuote: false,
    bracketSpacing: true,
    plugins: ["prettier-plugin-solidity"],
    overrides: [
        {
            files: "*.sol",
            options: {
                parser: "solidity-parse",
            },
        },
    ],
};
