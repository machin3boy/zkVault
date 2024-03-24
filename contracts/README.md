## Deployment Sequence:

1. **Set Compiler:**
   - Set compiler to version 0.8.24, EVM version Paris, with 200 optimizations.

2. **Deploy Contracts:**
   - Deploy the Password Verifier contract.
   - Deploy the MFAManager contract.
   - Deploy the zkVaultCore contract, passing the address of the MFAManager contract.
   - Deploy the zkVaultMFA contract, passing the address of the Verifier contract and the address of the zkVaultCore contract.
   - Set the zkVaultMFA Address in the MFAManager contract by calling the `setzkVaultMFAAddress` function.
   - Set the Password Verifier address in zkVaultCore.
   - Deploy the ExternalSignerMFA contracts (for 0x1111 and 0x2222), passing the address of the external signer.
   - Deploy TestERC20.
   - Deploy TestERC721.

## ExternalSignerMFA Addresses:

- ExternalSignerMFA 1:
  - Address: 0x1111697F4dA79a8e7969183d8aBd838572E50FF3
  - Key: 819843e94a6e40bb59127970c282468328cdeff87ef58299daa9ff1b98400f67

- ExternalSignerMFA 2:
  - Address: 0x2222E49A58e8238c864b7512e6C87886Aa0B6318
  - Key: a76c92f6a95175ca91b6f8def794793ad5e28517e5bbdf870ca3eeb9da1816bb

## Test Sequence:

1. **Test ExternalSignerMFA Contract:**
   - Call the `setValue` function with valid and invalid parameters to ensure proper behavior.
   - Verify that the `MFARequestData` is correctly updated after calling `setValue`.
   - Test the `getMFAData` function to retrieve the stored MFA data.

2. **Test zkVaultMFA Contract:**
   - Register a username first with the setUsername function in zkVaultCore
   - Call the `setRequestPasswordHash` function from the zkVaultCore/zkVaultMFA contract and verify that the password hash is correctly set.
   - Call the `setMFAData` function with valid and invalid proof parameters and verify the expected behavior.
   - Test the `getMFAData` function to retrieve the stored MFA data.

3. **Test MFAManager Contract:**
   - Register and deregister MFA providers using the respective functions.
   - Call the `setMFAProviders` function and verify that the MFA providers are correctly set for a given username and request ID.
   - Test the `verifyMFA` function with valid and invalid MFA provider data and proof parameters.
   - Verify that the `getVaultRequestMFAProviderCount` and `getVaultRequestMFAProviders` functions return the correct values.

4. **Test zkVaultCore Contract:**
   - Set a username and password hash using the `setUsername` function.
   - Lock an asset (ERC20 or ERC721) using the `lockAsset` function and verify that the mirrored tokens are minted correctly.
   - Verify that the `MirroredERC20Minted` and `MirroredERC721Minted` events are emitted with the correct data.
   - Test the `unlockAsset` function by providing valid MFA data and verifying that the original tokens are transferred back to the user and the mirrored tokens are burned.
   - Test the `batchLockAndSetMFA` and `batchUnlockAndVerifyMFA` functions with various combinations of MFA providers and verify the expected behavior.

5. **End-to-End Tests:**
   - Perform a complete flow of locking an asset, setting MFA data, and unlocking the asset using the zkVaultCore contract.
   - Verify that the MFA verification process works correctly and the assets are transferred as expected.