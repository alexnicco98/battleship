// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

/**
 * @title MerkleProof
 * @dev Provides utility functions for verifying Merkle proofs.
 */
contract MerkleProof {

    struct ProofVariables{
        bytes32[] proof; 
        bytes32 root;
        bytes32 leaf;
        uint8[2] index;
    }

    event CorrectProofEvent(bool returnValue);

    function verifyGeneratedProof(ProofVariables memory _proofVar) public pure returns (bool) {
        bytes32 h;
        bytes32 currentHash = _proofVar.leaf;

        for (uint256 i = 0; i < _proofVar.proof.length; i++) {
            bytes32 el = _proofVar.proof[i];

            if (_proofVar.index[1] % 2 == 0) {
                h = keccak256(abi.encodePacked(currentHash, el));
            } else {
                h = keccak256(abi.encodePacked(el, currentHash));
            }

            // Update the current hash
            currentHash = h;

            // Update the sibling index
            _proofVar.index[0] = uint8(_proofVar.index[0]) / 2;
            _proofVar.index[1] = uint8(_proofVar.index[1]) / 2;
        }

        return h == _proofVar.root;
    }



    function checkProofOrdered(ProofVariables memory _proofVar) public pure returns (bool) {
        return processProof(_proofVar) == _proofVar.root;
    }

    function processProof(ProofVariables memory _proofVar)
    internal pure returns (bytes32){
        bytes32 computedHash = _proofVar.leaf;
        for (uint256 i = 0; i < _proofVar.proof.length; i++) {
            computedHash = _hashPair(computedHash, _proofVar.proof[i]);
        }
        return computedHash;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : 
                       keccak256(abi.encodePacked(b, a));
    }

    // from StorJ -- https://github.com/nginnever/storj-audit-verifier/blob/master/contracts/MerkleVerifyv3.sol
    // check the function to work with the other code
    /*function verifyLeafWithMerkleRoot(bytes32 leaf, bytes32[] memory proof, bytes32 merkleRoot) 
    public pure returns (bool) {
        bytes32 currentHash = leaf;

        
        for (uint256 i = 0; i < proof.length; i++) {
            if (i % 2 == 0) {
                currentHash = keccak256(abi.encodePacked(currentHash, proof[i]));
            } else {
                currentHash = keccak256(abi.encodePacked(proof[i], currentHash));
            }
        }
        
        return currentHash == merkleRoot;
    }*/
    
    /*function checkProofOrdered(ProofVariables memory _proofVar) 
    public pure returns (bool) {
        bytes32 el;
        bytes32 h;
        uint256 remaining;
        bool isHashed = false;

        bytes memory proofBytes = abi.encodePacked(_proofVar.proof);

        for (uint256 j = 32; j <= proofBytes.length; j += 32) {
            assembly {
                el := mload(add(proofBytes, j))
            }

            // calculate remaining elements in proof
            remaining = (proofBytes.length - j + 32) / 32;

            while (remaining > 0 && _proofVar.index[1] % 2 == 1 && 
            _proofVar.index[0] > 2 ** remaining) {
                _proofVar.index[0] = uint8(_proofVar.index[0]) / 2 + 1;
            }

            if (!isHashed) {
                if (_proofVar.index[1] % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, _proofVar.index[0], _proofVar.index[1]));
                    _proofVar.index[1] = uint8(_proofVar.index[1]) / 2;
                } else {
                    h = keccak256(abi.encodePacked(_proofVar.index[0], _proofVar.index[1], el));
                    _proofVar.index[1] = uint8(_proofVar.index[1]) / 2 + 1;
                }
                isHashed = true;
            } else {
                if (_proofVar.index[1] % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, h));
                    _proofVar.index[1] = uint8(_proofVar.index[1]) / 2;
                } else {
                    h = keccak256(abi.encodePacked(h, el));
                    _proofVar.index[1] = uint8(_proofVar.index[1]) / 2 + 1;
                }
            }

            // Check if the calculated hash matches the hash at the corresponding 
            // index in the proof
            if (h != _proofVar.leaf) {
                return false;
            }
        }

        return h == _proofVar.root;
    }*/

    function pow(uint256 _base, uint256 _exponent) internal pure returns (uint256) {
        if (_exponent == 0) {
            return 1;
        }

        uint256 result = _base;
        for (uint256 i = 1; i < _exponent; i++) {
            result = result * _base;
        }

        return result;
    }
  
    
    /*function createProof(bytes32 leafHash, bytes32 previousLeafHash, uint256 index) 
    public pure returns (bytes32) {
        bytes32[] memory proof;

        // Initialize the variables.
        bytes32 h = leafHash;
        bool isHashed = false;

        // Iterate over the proof, calculating the leaf of each element.
        for (uint256 i = 0; i <= index; i++) {
            if (!isHashed) {
                if (i % 2 == 0) {
                    proof[i] = keccak256(abi.encodePacked(h, previousLeafHash));
                } else {
                    proof[i] = keccak256(abi.encodePacked(previousLeafHash, h));
                }
                isHashed = true;
            } else {
                if (i % 2 == 0) {
                    proof[i] = keccak256(abi.encodePacked(h, proof[i - 1]));
                } else {
                    proof[i] = keccak256(abi.encodePacked(proof[i - 1], h));
                }
            }
        }

        return proof[index];
    }


   function checkProofOrdered(ProofVariables memory proofVar) public returns (bool) {
        bytes32 el;
        bytes32 h;
        uint256 remaining;
        bool isHashed = false;
        bytes32 localProof = proofVar.proof;

        for (uint256 j = 32; j <= proofVar.proof.length; j += 32) {
            assembly {
                el := mload(add(localProof, j))
            }

            // calculate remaining elements in proof
            remaining = (proofVar.proof.length - j + 32) / 32;

            if (!isHashed) {
                if (proofVar.index[0] % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, proofVar.previousLeafHash));
                    proofVar.index[0] = proofVar.index[0] / 2;
                } else {
                    h = keccak256(abi.encodePacked(proofVar.previousLeafHash, el));
                    proofVar.index[0] = uint8(proofVar.index[0]) / 2 + 1;
                }
                isHashed = true;
            } else {
                if (proofVar.index[0] % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, h));
                    proofVar.index[0] = proofVar.index[0] / 2;
                } else {
                    h = keccak256(abi.encodePacked(h, el));
                    proofVar.index[0] = uint8(proofVar.index[0]) / 2 + 1;
                }
            }
        }
        
        for (uint256 j = 32; j <= proofVar.proof.length; j += 32) {
            assembly {
                el := mload(add(localProof, j))
            }

            // calculate remaining elements in proof
            remaining = (proofVar.proof.length - j + 32) / 32;

            if (!isHashed) {
                if (proofVar.index[1] % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, proofVar.previousLeafHash));
                    proofVar.index[1] = proofVar.index[1] / 2;
                } else {
                    h = keccak256(abi.encodePacked(proofVar.previousLeafHash, el));
                    proofVar.index[1] = uint8(proofVar.index[1]) / 2 + 1;
                }
                isHashed = true;
            } else {
                if (proofVar.index[1] % 2 == 0) {
                    h = keccak256(abi.encodePacked(el, h));
                    proofVar.index[1] = proofVar.index[1] / 2;
                } else {
                    h = keccak256(abi.encodePacked(h, el));
                    proofVar.index[1] = uint8(proofVar.index[1]) / 2 + 1;
                }
            }
        }

        emit CorrectProofEvent(h == proofVar.rootHash);
        return h == proofVar.rootHash;
    }*/



    /*function checkProofsOrdered(bytes32[] memory proofs, bytes32 root, bytes32 leafs) 
    public returns (bool){
      bool valid = true;

      //Loop through the Leafs
      //uint8 leaf;

      for(uint8 i = 0; i < 100; i+=5)
      {
        bytes32 proof = proofs[i];
        //leaf = getSlice(i+1, i+4, leafs);
        uint8 index = i+1;
        ProofVariables memory proofVar = ProofVariables({
                proof: proof,
                rootHash: root,
                previousLeafHash: leafs,
                index: index
        });
        bool result = checkProofOrdered(proofVar);
        if(!result) {
            valid = false;
            break;
        }
      }
      return valid;
  }*/


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

    function getSlice(uint8 begin, uint8 end, uint8 value) internal pure returns (uint8) {
        require(end >= begin, "Invalid slice range");
        require(end <= 8, "End position exceeds uint256 size");

        uint8 mask = uint8((2 ** (end - begin + 1)) - 1);
        return (value >> begin) & mask;
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
    }*/




}
