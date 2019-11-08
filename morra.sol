pragma solidity >=0.4.22 <0.6.0;

contract Morra {
    address payable public player1_address;
    address payable public player2_address; 
    
    bytes32 player1_choice_hash;
    bytes32 player1_guess_hash;
    bytes32 player2_choice_hash;
    bytes32 player2_guess_hash;
    
    uint256 public player1_choice;
    uint256 public player1_guess;
    uint256 public player2_choice;
    uint256 public player2_guess;
    uint256 public winning_guess;

    bool player1_paid_deposit = false;
    bool player1_revealed     = false;
    bool player1_committed    = false;
    
    bool player2_paid_deposit = false;
    bool player2_revealed     = false;
    bool player2_committed    = false;
    
    uint256 constant deposit_value = 9 ether;
    uint256 game_deposit = 0;
    
    uint public reveal_time;
    uint8 first_revealer = 0;


    modifier valid_choice(uint256 _choice) {
        require(_choice >=1 && _choice <= 5);
        _;
    }
    
    function register_for_game() public {
        // player can register for the game only once
        require(msg.sender != player1_address && msg.sender != player2_address);
        
        if (player1_address == address(0))
            player1_address = msg.sender;
        else if (player2_address == address(0))
            player2_address = msg.sender;
    }

    function deposit() public payable {
        // ensure player sends at least deposit amount of money
        require(deposit_value == msg.value);
        // deposit possible only after players registered
        require(msg.sender == player1_address || msg.sender == player2_address);
        
        if (msg.sender == player1_address) {
            require(player1_paid_deposit == false);     // ensure player doesn't pay deposit twice
            player1_paid_deposit = true;
        }
        else if (msg.sender == player2_address) {
            require(player2_paid_deposit == false);
            player2_paid_deposit = true;
        }

        game_deposit += msg.value;
    }

    function commit(uint256  _choice, uint256 _guess, string memory _secret_string) public valid_choice(_choice){
        // only registered player can commit
        require(msg.sender == player1_address || msg.sender == player2_address);
        
        if (msg.sender == player1_address) {
            // player can only commit after they paid for deposit
            require(player1_paid_deposit == true);      
            player1_choice_hash = keccak256(abi.encodePacked(_choice, _secret_string));
            player1_guess_hash  = keccak256(abi.encodePacked(_guess, _secret_string));
            player1_committed   = true;
        }
        else if (msg.sender == player2_address) {
            // player can only commit after they paid for deposit
            require(player2_paid_deposit == true);
            player2_choice_hash = keccak256(abi.encodePacked(_choice, _secret_string));
            player2_guess_hash  = keccak256(abi.encodePacked(_choice, _secret_string));
            player2_committed   = true;
        }
    }
    
    function determine_first_revealer() private view returns (uint8) {
        if (msg.sender == player1_address)
            return 1;
        
        // function called only by registered player 
        // if not called by the 1st one then necessarilly called by the 2nd one
        return 2;
    }
    
    function reveal(uint256  _choice, uint256  _guess, string memory _secret_string) public {
        // only registered player can reveal
        require(msg.sender == player1_address || msg.sender == player2_address);
        // only allow reveal after both players committed
        require(player1_committed == true && player2_committed == true);
        
        require(msg.sender == player1_address && keccak256(abi.encodePacked(_choice, _secret_string)) == player1_choice_hash ||
                msg.sender == player2_address && keccak256(abi.encodePacked(_choice, _secret_string)) == player2_choice_hash);

        if (msg.sender == player1_address && keccak256(abi.encodePacked(_choice, _secret_string)) == player1_choice_hash) {
            player1_choice = _choice;
            player1_guess  = _guess;
            player1_revealed = true;
        }
        else if (msg.sender == player2_address && keccak256(abi.encodePacked(_choice, _secret_string)) == player2_choice_hash) {
            player2_choice = _choice;
            player2_guess  = _guess;
            player2_revealed = true;
        }

        // start timer after 1st reveal; note that any player can reveal first
        if (reveal_time == 0) 
            reveal_time = now;
            first_revealer = determine_first_revealer();
        
    }
    
    function send_money_to_winner() private {
        if (first_revealer == 1)
            // send all money to 1st player
            player1_address.transfer(address(this).balance);

        if (first_revealer == 2)
            // send all money to 2nd player
            player2_address.transfer(address(this).balance);
    }
    
    function determine_winner() public{
        require(player1_revealed == true || player2_revealed == true);
        require(msg.sender == player1_address || msg.sender == player2_address);
        
        // if a player decides not to reveal after the other one has done so,
        // it might be intentional because they know the player who revealed will win the game
        // therefore, set all money (both deposits) to the first revealer 1 day after first reveal
        if (now > reveal_time + 60 * 60 * 24)
            send_money_to_winner();
        
        winning_guess = player1_choice + player2_choice;
        
        if (player1_guess == winning_guess && player2_guess != winning_guess) {
            // send deposit + winning guess to player1    
            player1_address.transfer(winning_guess* (10**18) + deposit_value);
            // send the rest to player2
            player2_address.transfer(address(this).balance);
        } 
        else if (player2_guess == winning_guess && player1_guess != winning_guess) {
            // send deposit + winning_guess to player2_guess
            player2_address.transfer(winning_guess* (10**18) + deposit_value);
            // send the rest to player1 
            player1_address.transfer(address(this).balance);
        } 
        else {
            // draw: send deposit to each player back (deposit == balance/2)
            player1_address.transfer(address(this).balance/2);
            player2_address.transfer(address(this).balance);
        }
            
    }
    
}