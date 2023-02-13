const { splitSignature } = require("ethers/lib/utils");
const { constants } = require("ethers");


async function getPermitSignature({
    wallet,
    token,
    spender,
    value
}) {
    const nonce = await token.nonces(wallet.address);
    const name = await token.name();
    const version = '1';
    const chainId = await wallet.getChainId();
    const deadline = constants.MaxUint256;


    return splitSignature(await wallet._signTypedData({
        name,
        version,
        chainId,
        verifyingContract: token.address,
    }, {
        Permit: [
            {
                name: 'owner',
                type: 'address',
            }, 
            {
                name: 'spender',
                type: 'address'
            },
            {
                name: 'value',
                type: 'uint256'
            },
            {
                name: 'nonce',
                type: 'uint256'
            },
            {
                name: 'deadline',
                type: 'uint256'
            }
        ],
    },
    {
        owner: wallet.address,
        spender,
        value,
        nonce,
        deadline
    }
    ));
}

module.exports = { 
    getPermitSignature
}