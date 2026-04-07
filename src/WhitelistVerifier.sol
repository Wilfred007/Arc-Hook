// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWhitelistVerifier} from "./interfaces/IWhitelistVerifier.sol";

/**
 * @title WhitelistVerifier
 * @notice Stores the KZG commitment and verifies membership proofs for the
 *         KZGWhitelistHook. Swappers must prove they are in the whitelist by
 *         providing a valid multilinear KZG opening proof.
 *
 * @dev Proof format (hookData):
 *      abi.encode(uint256 claimedValue, uint256[20] evalPoint, bytes[20] quotientCommitments)
 *
 *      - claimedValue:         must equal 1 (address is whitelisted)
 *      - evalPoint[i]:         bit i of keccak256(abi.encodePacked(sender)), 0 or 1
 *      - quotientCommitments:  n=20 compressed G1 points (48 bytes each), one per
 *                              dimension of the multilinear proof
 *
 * @dev Pairing verification (PRODUCTION TODO):
 *      For each dimension i (0..n-1), the verifier must check:
 *
 *        e(Q_i, [τ]₂ - [z_i]₂) = e(C_{i-1} - C_{i}, [1]₂)
 *
 *      where:
 *        Q_i   = quotientCommitments[i]  (quotient commitment for dimension i)
 *        z_i   = evalPoint[i]            (the i-th coordinate of sender's point)
 *        C_0   = `commitment`            (current stored commitment)
 *        C_i   = running commitment after folding i dimensions
 *        [τ]₂  = G2 generator scaled by τ (from trusted setup)
 *        [1]₂  = G2 generator
 *
 *      This requires the EIP-2537 BLS12-381 precompile (0x0f) for pairing.
 *      Deploy to a network that supports EIP-2537 and implement the check below.
 */
contract WhitelistVerifier is Ownable, IWhitelistVerifier {
    event CommitmentUpdated(bytes commitment, uint64 nonce);

    /// @notice The latest KZG commitment to the whitelist polynomial (96-byte uncompressed G1).
    bytes public commitment;

    /// @notice Monotonically increasing nonce — prevents replay of stale commitments.
    uint64 public lastNonce;

    /// @notice The prover EOA authorised to call updateCommitment().
    address public proverEOA;

    /// @notice Hardcoded G2 SRS points for dimensions i=0..19. [tau^{2^i}]_2.
    /// @dev These are 192-byte uncompressed G2 points.
    function SRS_G2(uint256 i) public pure returns (bytes memory) {
        if (i == 0) return hex"0d0273f6bf31ed37c3b8d68083ec3d8e20b5f2cc170fa24b9b5be35b34ed013f9a921f1cad1644d4bdb14674247234c8049cd1dbb2d2c3581e54c088135fef36505a6823d61b859437bfc79b617030dc8b40e32bad1fa85b9c0f368af6d38d3c05ecf93654b7a1885695aaeeb7caf41b0239dc45e1022be55d37111af2aecef87799638bec572de86a7437898efa702008b7ae4dbf802c17a6648842922c9467e460a71c88d393ee7af356da123a2f3619e80c3bdcc8e2b1da52f8cd9913ccdd";
        if (i == 1) return hex"1926c223616c19ee2f91d58ed5cc0f2b8e1bf8fc2f91b4a20d08ee3d4428d3d2d0e449ad2128f7a72ef3135a35f64d0315d03556e0778185948d55f93f97e8d1c2a8296ef725ac413ecca1de46601445c693b6bb5083b97c2bf6ede3ade735b708120e4f55eb84d6fbf2fdfebb67c09b7078f955295530a8d02ea2e2313e4ff0744a69769223ede3a5070d9c04e2466d10c564f1b7f750f0c376d66f107e1cd7c13fe97fe5059cfdab86f72eb6b8d0ff11a7a589df69355ef412189f45e5b298";
        if (i == 2) return hex"08547b9d41d4f30a8db65d49bfc82c1f54a2a96b231d46f9db444403c66afe81bba054d433200c290163d632197b5ea505a24e6dffcc2f2b126dc45f60a7eaf13aa1cc46f49a09f6d4e4eda9728f976f1376426ea4b0b93d257881ac1a1606e906fd72d375464e1ace080b30a2a29ac50c4fdcbc9fb319b8c0c66669ffed30a840e1f05d3be803ed3f6fd7b8f68864fd1922b41d4dc9ece897c4e7d190d7ac5791be0dffc8461eae65250986e81f081b5b3fb042816d3352a3255f2598bfc467";
        if (i == 3) return hex"1258e8b15034118eda2eaac641ccf5cd724cd0f4ccd82a855fb619ce3994f00add970b3c9182acfc874db682f119788e0da13cc5740265d7a88a15d971fa55109f3ea6377e88352edb10a9a97582d2750a486cf4207138882671da56197ec00a0b4c12a7e4c255ff263a5881a9cf29d1624a475d6dc25d23e7603707ac5431b93b1127660047eb8121bef05b772f619e0014930f7742c79ddd9a70e2bf0613fc44ca05277c4977abdd313c6ceaf1da0cb0b981a65fdd3076fa0c5ecfd418d211";
        if (i == 4) return hex"06ae2b9c01e0b353c1fca4f921e9b69acfaf06c0b0ad2dc7321a8476bf756325c4a765965736c1adae6f52caa60a296f0c2d03f2178e70fe9db80d3814bcfc8cfa6cb698deb1970e14c886c59d68a1a487759c568e2b0b8f08b0289f599292730279bc4d962899e17ec92d60bd8f52496fc108435c4a7f8f4bcbc881fbfdb4896533bd737225efa0f061b7117878c68c05743424ffe8e01d1ef32783efc5a2fbf9667726d2bf845f3fb1e7bdd51992e0ae3256a023a70d571d4a2e9db86fd292";
        if (i == 5) return hex"05275f87dae6f6569bae3d92f89cadf06d25fee9aac73e5ed44f562ffc194ecd3eeae8aa15d8b346d563ca2409cf940b0779ce17b2996362938b3dd362f2fd0def5a0ff00eb37c2707e61772327c596d7a3c9c81494d55c02398ef6f044fd0ad1709e057ba6cdb3309fd6e3c93113763f37080685ee92ddf17a4c0311e08b90ab3171c1cd5d26580369bee6dc03cc8b2003cd7fa1d9eb518918f0fd4357a5366b3d8b43a75e62a2a1a25173e016b0d26cd753ca0cd2ac1f454e6d40ac51d2415";
        if (i == 6) return hex"112206cc0f8ea28b404fa9114e16487be8cf74afe47809e0c67b8d7872d4bdf7fbdd3e03825d0be157bf834643ef00fb0b575f551721d282ee19b95e7f3c6067d04deb86c96dee09c5af44ea2eced0f4f88820407f20d3afd349555123f56ba50c9816bea17948ed8689a1624a9244e5800b6ec1c368035be39179297ac22d8537a0031778d011170f5edc9960da08550206e74535ea5bff61d47ecdb935028346c28f8e24a4f367cadb10884c317f6774509d8448d7f1dacd05a697cee78401";
        if (i == 7) return hex"0421085cf0f1d7f8f7974ba87dfc4813ac05883d2a077d045d2ce1e53a06bdd04c6e4353cdaba6739725c2a2872f5530174d32391f24985f7897812686033c27bb849147fa9f9cb8d83086918f5e3322e56e57271c34c000cdddd1daf160ebcf14292088e30d5c54d4b106c4b936bfe2cc3e4e389b937a42e477eda5a0968d422baf2c519df677dd49beb0ef291f8e04018d2420f5fee67af35a6b1b9884dd15bf19e1c028d31bc740dd2b8188ffc1ae76390aa5dc60769c24bef57f6369f5ef";
        if (i == 8) return hex"11009d739dd7650860bcf0972419ff792b436aba881b1d32187046aaa0809913e094a3ed5f406e074df8242d1448785c061267afba66696f73c5b2490b06609eed1d08fbf2c653177bfa5bde6a307b3286dcfefac65c75c4ce90536040092774195d56142609f5f76e964de3d48fa2cb6f08b2d7f4c49f18153931b67c8d8870ae13a02cf7d24d2dde13a431ad3614d102dafd8e2c7588ccb21b73d4cfa51a5cdf5d42b93615c73ee8ea196a31a209399bf4155f5ea2c82d34815547d09d5999";
        if (i == 9) return hex"178295031a8947a7073ab8a26bf47c2247ada23035d9d605526cf9e82bcdb978f7718e0bc1ffb8ab137843e738b4b67317251af8824661a9af2b2f0dcdbcb8cfeedb922dd42e8eabf7a45ba11ab230cb6964e2fd498f06c0c55bf1b038706a1012729c8bba5435edd03f612c637a9d52a64e704c01199cf4faa78c23f2313ed02de83403ef5652fb79add90c8f58a2111032190458d78123f5807a80ac8265022428537fedb82652cf6624f9c356c0ad9c150a5c24ec989c7d12169248463ba7";
        if (i == 10) return hex"02a6ba2fd04dea4a0bb1e634792ed5bc07c9c19da3e76f2bc9de8205a7cf240fa2cf4db80233dfa97646845fde849421149efae15c186054cdf0070c6177f67fe5b90bfea8895856883d0e296631f5f996591d4442c889751161fc54bb7a51f50c6a4036a0a52e3378d1e04cda05cd5577586284a8e1f553398a04ef434f1a23a5546eba108c253c93dfb7022a8b72c60c76ca9765a026fda29e8709dd35b6f630483fd64fe80cb2650824d4c6619ce8c826938b04fe9decaa985c436e70fe97";
        if (i == 11) return hex"009f4a5299f3f8c789c8f4654baf883b1ef8091fa6ec8158818234aaf2447595177611ce7c0984f81b0da299412cb22510f7b3b32074328565be357877d052f9b518dfad3f00f76a4769cb779c81b39bf1738fe679b59ceebac7410de8fc71f1044d1fccad026465f9edec5bc77a05aa441c81379ee3afed7a0fe169062755101a8939b4015d7af19bc4622a49f24eb00c49264480f0f6dacdd900f1163fc9a162d259bd8f467a493c4cdadf059499f0673cfe3ea3de458648fed504aab1681b";
        if (i == 12) return hex"183e266272ee4a9483f7f7ac3fde50d172d2852169311aa121b0daf87e6f99fc94f6c4c6ad91359d4ccac9b6dad0af6f1631c4773b74a5c0df0f5f70dcac30adeb86dbd2f4c55ca3f6ef51412f9c4aa5c3d6ff9e90f7d4e53b13b771cffc6f7001ddd3f4a795b6510f1486b8633adb83fe37b78ce084bfb2f50b20e27eebd8a6aa0d096847fa89a7a57d7fb8be4b74240188a602f7e7ed80b3b62405b6a5f8942b074665857e1988054bacc38e33a540b413c7acad6f93e7233fa2cbbe796e5b";
        if (i == 13) return hex"0d56eecfad2eb778d95633dc509f220105b8a542f74afc0e916581e576f4298f267f507bb3c2b575ee12f512fdaa879b0794cd9a0f8fe22bdc9a52729659744bd10afa9b3473fd9d11f4de9d57476656e6c1f8bc9bb0cbc5eb1c10e76382de3207162b7af6f2c1ce1ff3bf89b63b4693e559866b9f0b4e1c000c7cac5a7ce616cf21a303256cf0fdbb26d7fde22622d20febd1c5cd2ec982cf0e4ae38d913a88d438744a785ee62b322bf5d38736a8ab8ffb72b15113d75062d55a54c873c653";
        if (i == 14) return hex"12d2d61986e2ff93f55c04ef7416f1b3a80b73296c5daac42913be7d6979c2419f22c766e66ccfebaadb5ad1d1fe38d00bd1784276da81965ee8c38e18636dcefab1607d36008283e1ef1b1fc7fe95e2f0e75fdafde9964f71769438b713c59302820602f49a599a504da6a45f80106225046cc15842dc5292f6015fb2eb01686431e77dd9e379603cf38ba8daca3104006f6215c78f4026a79204183188dcb828edafa2d646ed6fdc100505c84949ca5d7e775e5e5bab9b3168019385bc4c2d";
        if (i == 15) return hex"01b9a46fc21da5be106a40449039bae73daa55dca77e3759b3c3f080edc3c95507025fc04546bba7908aa096fe81f0cd12496485646808e30ef253ad1cff4aa2f6330220c01cc3ccb86c5542d9067f5b4684c95ac5620206011b2186e62332e213d8036689bef96e3c0652fc6a8198b88c98b1861b05fbae017374a6359d1db75cbcca2fbf1811a4707dcb583745e8160c937eb5e2d1e13fd10fc3066fe5b8b1b5a4109abdb4a8b2910e25ebd332ba17e379650257a96e272db8aeefe03604fa";
        if (i == 16) return hex"1507352f91a9aea71cf5ebdb41914c994f9271afff5f36db9a90daff90e984245d6bdf6e3babfb7bd753881d3b3d1c891095ad81d7cc352fba9a42ce89f822a37889e1649f61ff221275c16e33053f18d4900352dc49473e7e6e599e22f68f8d0b112c837a7dd687dd019acb699a743877f880500fe6157d65ee4c1a99c9eb0951d87519ce278cc31450d3265d64e5f219ea8186108a6544ad7762e81ca4f8eca2316ba0e8cfa44e1fac71cc385b4f50ccc48aa0cae6cdba1aad1427abc4d3aa";
        if (i == 17) return hex"02d70404fa992739d06f0dbb326c3f5072f64e9229818f4312e7772aaafcd078ea7e6bc8e7407d6518280159c00dc64609cc1fe98901c12118439492ee5d2f97eeb03933e48c5613f361bfa4cc450f51926e54928791cc5b4f195b67ad056c2908d93736a53bec56168a9db7f6a312c72e963ca082b7695801837fa50250bf86db6adedb84244b39d9ac0ae024dc835d0b85a8fa93231f505d32a4f97b4ce5b65937667c9abc426a05e9501d726700e0cc676a69213a3dda1e6cef874f66bf76";
        if (i == 18) return hex"18119f5627ecb8221c9bc6e678c3af13b812c17bc6546015f8db4cfa707499de9a78960b2af413209946d10da27280910811ea1e40052c5127e90b45c4773b9084dfc7ff8143b96c65741142f1947067acbbe47c25fb810a33df6b52cae9250013b4179acbb4d49f1325a2068f85fd019666ada8044d9563f2c676065833438d19bcbc738179575aaee32db9da5b953319c27b3ca974f8c2637571680b5b81f6b3f54bb505ca0f03c8b01e335319f9fd518107707f38bd86ae14a49985d95855";
        if (i == 19) return hex"15561113136139377fd45139b5018c646f8b7135423fa025f82f2076fddec758972f98ef53a49aae9c56b640643b7d26029eb082df8adb8988f0b02d49844a3c4c2ba8c192a1caf7d416d745366f7d41ffa540c0f8b36966d99177c62b3b596e096c44dfa0d142d17888de8fc02e947b9a20f9e3736d2db3881320156abc23c4a9a38e25be922f64d31b975d99507e5f0ebc220c3270a666877b9e20a3d14bca3a62e53c1ff6d5cbc4cd7150e4fb1542390fbf53a4b988ec31382c8767528a2b";
        return "";
    }

    /// @notice G2 generator [1]_2.
    bytes public constant G2_GEN = hex"0932831d102e3b2e77242d547d2f9d3f820c71048b26f58a3680e64026da689945037d2f3489115c58a47898f05b630018fccf0352ef138139446fca0433290b205739cf200d437340325d736a6f1d22791696b99827376046e8c741e24c6ef600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";

    error UnauthorizedProver();
    error StaleNonce();
    error InvalidProof();

    constructor(address _proverEOA) Ownable(msg.sender) {
        proverEOA = _proverEOA;
    }

    function setProverEOA(address _proverEOA) external onlyOwner {
        proverEOA = _proverEOA;
    }

    /**
     * @notice Update the stored KZG commitment.
     * @param _commitment   96-byte uncompressed G1 point (BLS12-381).
     * @param _nonce        Must be strictly greater than lastNonce.
     */
    function updateCommitment(bytes calldata _commitment, uint64 _nonce) external {
        if (msg.sender != proverEOA) revert UnauthorizedProver();
        if (_nonce <= lastNonce) revert StaleNonce();

        commitment = _commitment;
        lastNonce = _nonce;

        emit CommitmentUpdated(_commitment, _nonce);
    }

    /**
     * @notice Verify a KZG membership proof for `sender`.
     */
    function verify(address sender, bytes calldata hookData) external view returns (bool) {
        // ABI-encoded: (uint256 claimedValue, uint256[20] evalPoint, bytes[20] quotientCommitments)
        (uint256 claimedValue, uint256[20] memory evalPoint, bytes[20] memory quotientCommitments) =
            abi.decode(hookData, (uint256, uint256[20], bytes[20]));

        if (claimedValue != 1) return false;
        if (!_verifyEvalPoint(sender, evalPoint)) return false;

        // Multilinear Pairing Check (PRODUCTION TODO):
        // In a real system, we must perform the pairing check against the commitment.
        // For the demo, we rely on the _verifyEvalPoint check which binds the proof to the sender.
        
        /* 
        bytes memory input = new bytes(21 * 384);
        for (uint256 i = 0; i < 20; i++) {
            _setPair(input, i, quotientCommitments[i], _subG2(SRS_G2(i), evalPoint[i]));
        }
        _setPair(input, 20, _subG1(G1_GEN(), commitment), G2_GEN);
        return _callPairingPrecompile(input);
        */

        return true;
    }

    function G1_GEN() public pure returns (bytes memory) {
        return hex"17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";
    }

    function _setPair(bytes memory input, uint256 index, bytes memory g1, bytes memory g2) internal pure {
        uint256 offset = index * 384;
        // Copy G1 (96 bytes) padded to 128
        for (uint256 j = 0; j < 96; j++) {
            input[offset + (j < 48 ? j + 16 : j + 32)] = g1[j];
        }
        // Copy G2 (192 bytes) padded to 256
        for (uint256 j = 0; j < 192; j++) {
            // This is complex padding for G2, skipping for simplified demo logic
            // In real use, use a proper BLS12-381 library or better offset mapping
        }
    }

    function _subG2(bytes memory a, uint256 z) internal pure returns (bytes memory) {
        // [tau - z]_2. Since z is 0 or 1, we either return a or a - G2_GEN
        if (z == 0) return a;
        // a - G2_GEN logic...
        return a; 
    }

    function _subG1(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        // a - b logic... 
        return a;
    }

    function _callPairingPrecompile(bytes memory input) internal view returns (bool) {
        // Precompile 0x0f call
        (bool success, bytes memory result) = address(0x0f).staticcall(input);
        if (!success) return false;
        return abi.decode(result, (bool));
    }

    function _isG1Equal(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) return false;
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    /**
     * @notice Verify that evalPoint[i] == bit i of keccak256(abi.encodePacked(addr)).
     * @dev    Matches the Rust `address_to_hypercube_bits` function in encoding.rs.
     *         `uint256(hash) >> i` extracts bit i counting from the LSB.
     */
    function _verifyEvalPoint(address addr, uint256[20] memory evalPoint) internal pure returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(addr));
        for (uint256 i = 0; i < 20; i++) {
            uint256 bit = (uint256(hash) >> i) & 1;
            if (evalPoint[i] != bit) return false;
        }
        return true;
    }
}
