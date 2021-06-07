// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

interface AccessControllerInterface {
    function hasAccess(address user, bytes calldata data)
        external
        view
        returns (bool);
}

contract AccessController is AccessControllerInterface {
    function hasAccess(address user, bytes calldata data)
        external
        view
        override
        returns (bool)
    {
        return true;
    }
}
