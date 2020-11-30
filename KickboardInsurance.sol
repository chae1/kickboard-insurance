// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./SafeMath.sol";

contract KickboardInsurance is ERC20 {
    using SafeMath for uint256;
    
    /**
     * Structures
     */
    struct Vote {
        bool voted;
        bool voted_accept;
    }
    
    struct Insurance {
        address owner;
        uint256 insurance_ID_user;
        bool is_finished;
        bool is_claimed;
        uint256 startTime_sec;
        uint256 duration_hour;
    }
    
    struct Claim {
        uint256 claim_ID;
        address owner;
        uint256 claim_ID_user;
        uint256 insurance_ID_user;
        bool is_closed;
        bool is_accepted;
        uint256 startTime_sec;
        uint256 claimed_amount_ETH;
        uint256 compensated_amount_ETH;
        uint256 accept_quantity;
        uint256 reject_quantity;
        mapping (address => Vote) votes;
    }
    
    struct User {
        bool is_member;
        uint256 pricePerHour_ETH;
        Insurance[] insurances; /* only the last element can be currently working */
        Claim[] claims; /* only the last element can be currently working */
    }
    
    struct Proposal {
        uint256 proposal_ID;
        address owner;
        bool is_closed;
        bool is_accepted;
        uint256 startTime_sec;
        uint256 _fundsUpperLimit_ETH;
        uint256 _pricePerHour_initial_ETH;
        uint256 _pricePerHour_lowerLimit_ETH;
        uint256 _pricePerHour_deductionRatioPerHour_percent;
        uint256 accept_quantity;
        uint256 reject_quantity;
        mapping (address => Vote) votes;
    }
    
    mapping (address => User) private UserInfo;
    Claim[] private claims;
    Proposal[] private proposals;

    /**
     * @dev Private variables
     * - Funds (ETH) surplus is distribute to governance token holders.
     * - Insurance price drops exponentially with coverage time and will be initialized after one submits a claim.
     */
    uint256 private _funds_ETH;
    uint256 private _fundsUpperLimit_ETH;
    uint256 private _pricePerHour_initial_ETH;
    uint256 private _pricePerHour_lowerLimit_ETH;
    uint256 private _pricePerHour_deductionRatioPerHour_percent;
    
    /**
     * Public functions
     */
    function kick_funds_ETH() public view returns (uint256) {
        return _funds_ETH;
    }
    
    function kick_fundsUpperLimit_ETH() public view returns (uint256) {
        return _fundsUpperLimit_ETH;
    }
    
    function kick_pricePerHour_initial_ETH() public view returns (uint256) {
        return _pricePerHour_initial_ETH;
    }
    
    function kick_pricePerHour_lowerLimit_ETH() public view returns (uint256) {
        return _pricePerHour_lowerLimit_ETH;
    }
    
    function kick_pricePerHour_deductionRatioPerHour_percent() public view returns (uint256) {
        return _pricePerHour_deductionRatioPerHour_percent;
    }
    
    function kick_join() public {
        UserInfo[msg.sender].is_member = true;
        UserInfo[msg.sender].pricePerHour_ETH = _pricePerHour_initial_ETH;
        UserInfo[msg.sender].insurances.push(Insurance({owner:address(0),
                                                        insurance_ID_user:0, 
                                                        is_finished:true,
                                                        is_claimed:false,
                                                        startTime_sec:now, 
                                                        duration_hour:0}));
                                                        
        UserInfo[msg.sender].claims.push(Claim({ claim_ID:0, 
                                                 owner:address(0), 
                                                 claim_ID_user:0, 
                                                 insurance_ID_user:0, 
                                                 is_closed:true, 
                                                 is_accepted:false,
                                                 startTime_sec:now, 
                                                 claimed_amount_ETH:0, 
                                                 compensated_amount_ETH:0, 
                                                 accept_quantity:0, 
                                                 reject_quantity:0}));
    }
    
    function kick_pricePerHour_ETH() public view returns (uint256) {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        return UserInfo[msg.sender].pricePerHour_ETH;
    }
    
    function kick_price_ETH(uint256 duration_hour) public view returns (uint256) {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        return duration_hour * UserInfo[msg.sender].pricePerHour_ETH;
    }
    
    function kick_start_new_insurance(uint256 duration_hour) payable public {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        require(is_current_insurance_finished(), "KickboardInsurance: current insurance is not finished");
        require(msg.value == price(msg.sender,duration_hour), "KickboardInsurance: paying amount is different from the price");
         
        uint256 new_insurance_ID_user = UserInfo[msg.sender].insurances.length;
        UserInfo[msg.sender].insurances.push(Insurance({owner:msg.sender,
                                                        insurance_ID_user:new_insurance_ID_user, 
                                                        is_finished:false,
                                                        is_claimed:false,
                                                        startTime_sec:now, 
                                                        duration_hour:duration_hour}));
        _funds_ETH = _funds_ETH.add(msg.value);
    }
    
    function kick_get_current_insurance() public view returns (address owner, 
                                                               uint256 insurance_ID_user, 
                                                               bool is_finished,
                                                               bool is_claimed,
                                                               uint256 startTime_sec, 
                                                               uint256 duration_hour) {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        
        uint256 current_insurance_ID_user = UserInfo[msg.sender].insurances.length - 1;
        
        Insurance storage current_insurance = UserInfo[msg.sender].insurances[current_insurance_ID_user];
        return (current_insurance.owner,
                current_insurance.insurance_ID_user,
                current_insurance.is_finished,
                current_insurance.is_claimed,
                current_insurance.startTime_sec, 
                current_insurance.duration_hour);
    }
    
    function kick_claim(uint256 insurance_ID_user, uint256 claimed_amount_ETH) public {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        require(is_current_claim_closed(), "KickboardInsurance: current claim is not closed" );
        require(UserInfo[msg.sender].insurances.length-1 >= insurance_ID_user, "KickboardInsurance: no such insurance id");
        
        uint256 new_claim_ID_user = UserInfo[msg.sender].claims.length;
        uint256 new_claim_ID = claims.length;
        
        UserInfo[msg.sender].claims.push(Claim({claim_ID:new_claim_ID, 
                                                owner:msg.sender,
                                                claim_ID_user:new_claim_ID_user, 
                                                insurance_ID_user:insurance_ID_user, 
                                                is_closed:false, 
                                                is_accepted:false,
                                                startTime_sec:now, 
                                                claimed_amount_ETH:claimed_amount_ETH, 
                                                compensated_amount_ETH:0, 
                                                accept_quantity:0, 
                                                reject_quantity:0}));
                                                
        UserInfo[msg.sender].insurances[insurance_ID_user].is_claimed = true;
        UserInfo[msg.sender].pricePerHour_ETH = _pricePerHour_initial_ETH;
        
        claims.push(Claim({              claim_ID:new_claim_ID, 
                                         owner:msg.sender, 
                                         claim_ID_user:new_claim_ID_user, 
                                         insurance_ID_user:insurance_ID_user, 
                                         is_closed:false, 
                                         is_accepted:false,
                                         startTime_sec:now, 
                                         claimed_amount_ETH:claimed_amount_ETH, 
                                         compensated_amount_ETH:0, 
                                         accept_quantity:0, 
                                         reject_quantity:0}));
    
        emit ClaimEvent(msg.sender, new_claim_ID, claimed_amount_ETH);
    }
    
    function kick_get_current_claim() public view returns (uint256 claim_ID, 
                                                           address owner,
                                                           uint256 claim_ID_user, 
                                                           uint256 insurance_ID_user,
                                                           bool is_closed,
                                                           bool is_accepted,
                                                           uint256 startTime_sec,
                                                           uint256 claimed_amount_ETH,
                                                           uint256 compensated_amount_ETH,
                                                           uint256 accept_quantity, 
                                                           uint256 reject_quantity) {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        
        uint256 current_claim_ID_user = UserInfo[msg.sender].claims.length - 1;
        
        Claim storage current_claim = UserInfo[msg.sender].claims[current_claim_ID_user];
        return (current_claim.claim_ID, 
                current_claim.owner,
                current_claim.claim_ID_user, 
                current_claim.insurance_ID_user,
                current_claim.is_closed,
                current_claim.is_accepted,
                current_claim.startTime_sec, 
                current_claim.claimed_amount_ETH,
                current_claim.compensated_amount_ETH,
                current_claim.accept_quantity, 
                current_claim.reject_quantity);
    }
    
    function kick_vote_on_claim(uint256 claim_ID, bool voted_accept) public {
        require(claims[claim_ID].votes[msg.sender].voted == false, "KickboardInsurance: already voted for the claim");
         
        Claim storage claim = claims[claim_ID];
        Claim storage claim_user = UserInfo[claim.owner].claims[claim.claim_ID_user];
        
        claim.votes[msg.sender].voted = true;
        claim.votes[msg.sender].voted_accept = voted_accept;
        claim_user.votes[msg.sender].voted = true;
        claim_user.votes[msg.sender].voted_accept = voted_accept;
        
        if (voted_accept) {
            claim.accept_quantity = claim.accept_quantity.add(balanceOf(msg.sender));
            claim_user.accept_quantity = claim_user.accept_quantity.add(balanceOf(msg.sender));
        }
        else {
            claim.reject_quantity = claim.reject_quantity.add(balanceOf(msg.sender));
            claim_user.reject_quantity = claim_user.reject_quantity.add(balanceOf(msg.sender));
        }
    }
    
    function kick_propose(uint256 _fundsUpperLimit_ETH, uint256 _pricePerHour_initial_ETH, uint256 _pricePerHour_lowerLimit_ETH, uint256 _pricePerHour_deductionRatioPerHour_percent) public {
        require(balanceOf(msg.sender) != 0, "KickboardInsurance: not a governance token holder");
        require(is_current_proposal_closed(), "KickboardInsurance: current proposal is not closed");
        
        uint256 new_proposal_ID = proposals.length;
        proposals.push(Proposal({proposal_ID:new_proposal_ID, 
                                 owner:msg.sender, 
                                 is_closed:false, 
                                 is_accepted:false,
                                 startTime_sec:now, 
                                 _fundsUpperLimit_ETH:_fundsUpperLimit_ETH, 
                                 _pricePerHour_initial_ETH:_pricePerHour_initial_ETH, 
                                 _pricePerHour_lowerLimit_ETH:_pricePerHour_lowerLimit_ETH, 
                                 _pricePerHour_deductionRatioPerHour_percent:_pricePerHour_deductionRatioPerHour_percent, 
                                 accept_quantity:0, 
                                 reject_quantity:0 }));
        
        emit ProposalEvent(msg.sender, _fundsUpperLimit_ETH, _pricePerHour_initial_ETH, _pricePerHour_lowerLimit_ETH, _pricePerHour_deductionRatioPerHour_percent);
    }
    
    function kick_get_current_proposal() public view returns (uint256 proposal_ID, 
                                                              address owner, 
                                                              bool is_closed,
                                                              bool is_accepted,
                                                              uint256 startTime_sec, 
                                                              uint256 _fundsUpperLimit_ETH, 
                                                              uint256 _pricePerHour_initial_ETH, 
                                                              uint256 _pricePerHour_lowerLimit_ETH, 
                                                              uint256 _pricePerHour_deductionRatioPerHour_percent,
                                                              uint256 accept_quantity, 
                                                              uint256 reject_quantity) {
                          
        uint256 current_proposal_ID = proposals.length - 1;
        Proposal storage current_proposal = proposals[current_proposal_ID];
        return (current_proposal.proposal_ID, 
                current_proposal.owner, 
                current_proposal.is_closed,
                current_proposal.is_accepted,
                current_proposal.startTime_sec, 
                current_proposal._fundsUpperLimit_ETH,
                current_proposal._pricePerHour_initial_ETH,
                current_proposal._pricePerHour_lowerLimit_ETH,
                current_proposal._pricePerHour_deductionRatioPerHour_percent,
                current_proposal.accept_quantity, 
                current_proposal.reject_quantity);
    }
    
    function kick_vote_on_proposal(uint256 proposal_ID, bool voted_accept) public {
        require(proposals[proposal_ID].votes[msg.sender].voted == false, "KickboardInsurance: already voted for the proposal");
        
        proposals[proposal_ID].votes[msg.sender].voted = true;
        proposals[proposal_ID].votes[msg.sender].voted_accept = voted_accept;
        
        if (voted_accept) {
            proposals[proposal_ID].accept_quantity = proposals[proposal_ID].accept_quantity.add(balanceOf(msg.sender));
        }
        else {
            proposals[proposal_ID].reject_quantity = proposals[proposal_ID].reject_quantity.add(balanceOf(msg.sender));
        }
    }
     
    function update() public {
        update_current_insurance();
        update_current_claim();
        update_current_proposal();
    }
     
    /**
     * Internal functions.
     */
    function price(address _address, uint256 duration_hour) internal returns (uint256) {
        return duration_hour * UserInfo[msg.sender].pricePerHour_ETH;
    }
    
    function is_current_insurance_finished() internal returns (bool) {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        User storage user = UserInfo[msg.sender];
        
        uint256 current_insurance_ID = user.insurances.length - 1;
        Insurance storage current_insurance = user.insurances[current_insurance_ID];
        return current_insurance.is_finished;
    }
    
    function is_current_claim_closed() internal returns (bool) {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        User storage user = UserInfo[msg.sender];
        
        uint256 current_claim_ID_user = user.claims.length - 1;
        Claim storage current_claim_user = user.claims[current_claim_ID_user];
        Claim storage current_claim = claims[current_claim_user.claim_ID];
        
        return current_claim.is_closed;
    }
    
    function is_current_proposal_closed() internal returns (bool) {
        uint256 current_proposal_ID = proposals.length - 1;
        Proposal storage current_proposal = proposals[current_proposal_ID];
        
        return current_proposal.is_closed;
    }
    
    function update_current_insurance() internal {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        User storage user = UserInfo[msg.sender];
        
        uint256 current_insurance_ID = user.insurances.length - 1;
        Insurance storage current_insurance = user.insurances[current_insurance_ID];
        
        if (current_insurance.is_finished) {
            return;
        }
        else {
            uint256 endTime_sec = current_insurance.startTime_sec.add(current_insurance.duration_hour.mul(1));
            if (now >= endTime_sec) {
                current_insurance.is_finished = true;
                if (current_insurance.is_claimed == false) {
                    uint256 P = user.pricePerHour_ETH;
                    uint256 D = current_insurance.duration_hour;
                    uint256 R = _pricePerHour_deductionRatioPerHour_percent;
                    
                    uint256 P_temp = P.mul((uint256(100).sub(R)).pow(D)).div(uint256(100).pow(D));
                    if (P_temp >= _pricePerHour_lowerLimit_ETH) {
                        user.pricePerHour_ETH = P_temp;
                    }
                }
            }
            else {
                return;
            }
        }
    }
    
    function update_current_claim() internal {
        require(UserInfo[msg.sender].is_member, "KickboardInsurance: not a member");
        User storage user = UserInfo[msg.sender];
        
        uint256 current_claim_ID_user = user.claims.length - 1;
        Claim storage current_claim_user = user.claims[current_claim_ID_user];
        Claim storage current_claim = claims[current_claim_user.claim_ID];
        
        if (current_claim.is_closed) {
            return;
        }
        else {
            uint256 endTime_sec = current_claim.startTime_sec + 1;
            if (now >= endTime_sec) {
                current_claim_user.is_closed = true;
                current_claim.is_closed = true;
                
                uint256 a = current_claim.accept_quantity;
                uint256 r = current_claim.reject_quantity;
                
                if (a.add(r) != 0 && uint256(100).mul(a).div(a.add(r)) >= 70  &&  uint256(100).mul(a.add(r)).div(totalSupply()) >= 70) {
                    uint256 claimed_amount = current_claim_user.claimed_amount_ETH;
                    
                    current_claim_user.compensated_amount_ETH = claimed_amount;
                    current_claim_user.is_accepted = true;
                    current_claim.compensated_amount_ETH = claimed_amount;
                    current_claim.is_accepted = true;
                    
                    msg.sender.transfer(claimed_amount);
                    _funds_ETH = _funds_ETH.sub(claimed_amount);
                }
            }
            return;
        }
    }
    
    function update_current_proposal() internal {
        uint256 current_proposal_ID = proposals.length - 1;
        Proposal storage current_proposal = proposals[current_proposal_ID];
        
        if(current_proposal.is_closed) {
            return;
        }
        else {
            uint256 endTime_sec = current_proposal.startTime_sec + 1;
            if (now >= endTime_sec) {
                current_proposal.is_closed = true;
                
                uint256 a = current_proposal.accept_quantity;
                uint256 r = current_proposal.reject_quantity;
                
                if (a.add(r) != 0 && uint256(100).mul(a).div(a.add(r)) >= 70  &&  uint256(100).mul(a.add(r)).div(totalSupply()) >= 70) {
                    _fundsUpperLimit_ETH = current_proposal._fundsUpperLimit_ETH;
                    _pricePerHour_initial_ETH = current_proposal._pricePerHour_initial_ETH;
                    _pricePerHour_lowerLimit_ETH = current_proposal._pricePerHour_lowerLimit_ETH;
                    _pricePerHour_deductionRatioPerHour_percent = current_proposal._pricePerHour_deductionRatioPerHour_percent;
                    
                    current_proposal.is_accepted = true;
                }
            }
            else {
                return;
            }
        }
    }
    
    
    
    
     
     
    /**
     * Constructor.
     */
    constructor() public ERC20("SafeQuick", "SFQ") {
        _mint(msg.sender, 10**decimals() * 100);
        
        _funds_ETH = 10**decimals() * 0;
        _fundsUpperLimit_ETH = 10**decimals() * 10; /* 10 ETH */
        _pricePerHour_initial_ETH = 10**decimals() / 10**3 * 2; /* 0.002 ETH */
        _pricePerHour_lowerLimit_ETH = 10**decimals() / 10**3 * 1; /* 0.001 ETH */
        _pricePerHour_deductionRatioPerHour_percent = 10; /* 10% deduction per 1 covered hour */
        
        claims.push(Claim({  claim_ID:0, 
                         owner:address(0), 
                         claim_ID_user:0, 
                         insurance_ID_user:0, 
                         is_closed:true, 
                         is_accepted:false,
                         startTime_sec:now, 
                         claimed_amount_ETH:0, 
                         compensated_amount_ETH:0, 
                         accept_quantity:0, 
                         reject_quantity:0}));

        proposals.push(Proposal({proposal_ID:0, 
                             owner:address(0), 
                             is_closed:true, 
                             is_accepted:false,
                             startTime_sec:now, 
                             _fundsUpperLimit_ETH:_fundsUpperLimit_ETH,
                             _pricePerHour_initial_ETH:_pricePerHour_initial_ETH, 
                             _pricePerHour_lowerLimit_ETH:_pricePerHour_lowerLimit_ETH, 
                             _pricePerHour_deductionRatioPerHour_percent:_pricePerHour_deductionRatioPerHour_percent, 
                             accept_quantity:0, 
                             reject_quantity:0}));
    }
    
    event ClaimEvent (address indexed owner, uint256 claim_global_ID, uint256 claimed_amount_ETH);
    event ProposalEvent (address indexed owner, uint256 _fundsUpperLimit_ETH, uint256 _pricePerHour_initial_ETH, uint256 _pricePerHour_lowerLimit_ETH, uint256 _pricePerHour_deductionRatioPerHour_percent);
}
