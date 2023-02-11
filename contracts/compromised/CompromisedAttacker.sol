pragma solidity ^0.8.0;

// Attack plan
// 1. Use private keys to manipulate Oracle price calculation
// 2. Buy token for a low price
// 3. Manipulate Oracle to increase price to the value of what Exchange is owning
// 4. Sell token for a high price