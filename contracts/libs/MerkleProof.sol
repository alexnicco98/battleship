// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

/**
 * @title MerkleProof
 * @dev Provides utility functions for verifying Merkle proofs.
 */
contract MerkleProof {

    event CorrectProofEvent(bool returnValue);

    function checkProofOrdered(bytes memory proof, bytes32 root, string memory hash, 
    uint256 index) public returns (bool) {
        // use the index to determine the node ordering
        // index ranges 1 to n

        bytes32 el;
        bytes32 h;
        uint256 remaining;
        bool isHashed = false;

        for (uint256 j = 32; j <= proof.length; j += 32) {
            assembly {
                el := mload(add(proof, j))
            }

            // calculate remaining elements in proof
            remaining = (proof.length - j + 32) / 32;

            if (!isHashed) {
                if (index % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, hash));
                    index = index / 2;
                } else {
                    h = keccak256(abi.encodePacked(hash, el));
                    index = uint(index) / 2 + 1;
                }
                isHashed = true;
            } else {
                if (index % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, h));
                    index = index / 2;
                } else {
                    h = keccak256(abi.encodePacked(h, el));
                    index = uint(index) / 2 + 1;
                }
            }

        }
        emit CorrectProofEvent(h == root);
        return h == root;
    }

    function checkProofsOrdered(bytes[] memory proofs, bytes32 root, string memory leafs) 
    public returns (bool){
      bool valid = true;

      //Loop through the Leafs
      string memory leaf = "";

      for(uint8 i = 0; i < 100; i+=5)
      {
        bytes memory proof = proofs[i];
        leaf = getSlice(i+1, i+4, leafs);
        uint8 index = i+1;
        bool result = checkProofOrdered(proof, root, leaf, index);
        if(!result) {
            valid = false;
            break;
        }
      }
      return valid;
  }


    function checkProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) 
    external pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash current computedHash with proofElement
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash proofElement with current computedHash
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == root;
    }

    function generateMerkleRoot(bytes32[] memory leafNodes) 
    internal pure returns (bytes32) {
        uint256 n = leafNodes.length;
        require(n > 0, "No leaf nodes provided");

        while (n > 1) {
            uint256 parentIndex = 0;
            for (uint256 i = 0; i < n; i += 2) {
                if (i + 1 < n) {
                    leafNodes[parentIndex] = keccak256(abi.encodePacked(leafNodes[i], leafNodes[i + 1]));
                } else {
                    leafNodes[parentIndex] = leafNodes[i];
                }
                parentIndex++;
            }
            n = (n + 1) / 2;
        }

        return leafNodes[0];
    }

    function getSlice(uint256 begin, uint256 end, string memory text) internal pure returns (string memory) {
        bytes memory a = new bytes(end-begin+1);
        for(uint i=0;i<=end-begin;i++){
            a[i] = bytes(text)[i+begin-1];
        }
        return string(a);
    }
    
    /**
     * @dev Verifies a Merkle proof for a leaf element.
     * @param leaf The hashed leaf element.
     * @param index The index of the leaf in the Merkle tree.
     * @param proof The Merkle proof nodes.
     * @param root The Merkle root to verify against.
     * @return true if the proof is valid, false otherwise.
     */
    /*function verifyMerkleProof(bytes32 leaf, uint256 index,
    bytes32[] memory proof, bytes32 root) public pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            if (index % 2 == 0) {
                computedHash = keccak256(abi.encodePacked(computedHash, 
                proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, 
                computedHash));
            }
            
            index = index / 2;
        }
        
        return computedHash == root;
    }

    // from StorJ -- https://github.com/nginnever/storj-audit-verifier/blob/master/contracts/MerkleVerifyv3.sol
    // check the function to work with the other code
    function checkProofOrdered(bytes memory proof, bytes32 root, 
    string memory hash, uint256 index) public pure returns (bool) {
        // use the index to determine the node ordering
        // index ranges 1 to n

        bytes32 el;
        bytes32 h;
        uint256 remaining;
        bool isHashed = false;

        for (uint256 j = 32; j <= proof.length; j += 32) {
            assembly {
                el := mload(add(proof, j))
            }

            // calculate remaining elements in proof
            remaining = (proof.length - j + 32) / 32;

            // we don't assume that the tree is padded to a power of 2
            // if the index is odd then the proof will start with a hash at a higher
            // layer, so we have to adjust the index to be the index at that layer
            while (remaining > 0 && index % 2 == 1 && index > 2 ** remaining) {
                index = uint(index) / 2 + 1;
            }

            if (!isHashed) {
                if (index % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, bytes(hash)));
                    index = index / 2;
                } else {
                    h = keccak256(abi.encodePacked(bytes(hash), el));
                    index = uint(index) / 2 + 1;
                }
                isHashed = true;
            } else {
                if (index % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, h));
                    index = index / 2;
                } else {
                    h = keccak256(abi.encodePacked(h, el));
                    index = uint(index) / 2 + 1;
                }
            }
        }

        return h == root;
    }
    */



}
