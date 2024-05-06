// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.12;

/// @title ICoreBorrow
/// @author Angle Labs, Inc.
/// @notice Interface for the `CoreBorrow` contract
/// @dev This interface only contains functions of the `CoreBorrow` contract which are called by other contracts
/// of this module
interface ICoreBorrow {
    /// @notice Checks if an address corresponds to a treasury of a stablecoin with a flash loan
    /// module initialized on it
    /// @param treasury Address to check
    /// @return Whether the address has the `FLASHLOANER_TREASURY_ROLE` or not
    function isFlashLoanerTreasury(address treasury) external view returns (bool);

    /// @notice Checks whether an address is governor of the Angle Protocol or not
    /// @param admin Address to check
    /// @return Whether the address has the `GOVERNOR_ROLE` or not
    function isGovernor(address admin) external view returns (bool);

    /// @notice Checks whether an address is governor or a guardian of the Angle Protocol or not
    /// @param admin Address to check
    /// @return Whether the address has the `GUARDIAN_ROLE` or not
    /// @dev Governance should make sure when adding a governor to also give this governor the guardian
    /// role by calling the `addGovernor` function
    function isGovernorOrGuardian(address admin) external view returns (bool);

    /// @notice Adds a governor in the protocol
    /// @param governor Address to grant the role to
    /// @dev It is necessary to call this function to grant a governor role to make sure
    /// all governors also have the guardian role
    function addGovernor(address governor) external;

    /// @notice Revokes a governor from the protocol
    /// @param governor Address to remove the role to
    /// @dev It is necessary to call this function to remove a governor role to make sure
    /// the address also loses its guardian role
    function removeGovernor(address governor) external;
}
