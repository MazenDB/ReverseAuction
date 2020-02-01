pragma solidity >=0.4.22 <0.6.0;
//pragma solidity 0.5.11;
contract Bidding{
    struct fog{
        bool exists;
        uint placed_bids;
        //reputation score
        uint deposit;
    }
    
    mapping (address => fog) public fog_suppliers;
    
    struct client{
      bool exists;
      uint deposit;
      //credbility
      bool auction_open;
    }
    
    mapping (address => client) public clients;
    
    struct bid{
        bool open;
        uint lowestBid;
        address payable lowestBidder;
        uint startTime;
        uint closingTime;
        uint [] metrics;
    }
    
    mapping (address=> bid) public Auctions;
    
    address payable private owner;
    
    uint totalBidders;
    
    modifier onlyOwner{
      require(msg.sender == owner,
      "Sender not authorized."
      );
      _;
    }
    
    modifier onlyClient{
      require(clients[msg.sender].exists,
      "Sender not authorized."
      );
      _;
    }
    
    modifier onlySupplier{
      require(fog_suppliers[msg.sender].exists,
      "Sender not authorized."
      );
      _;
    }
    
    event BidderRegistered(address supplierAddress);
    
    event ClientRegistered(address clientAddress);

    event BidderAbandoned(address supplierAddress);
    
    event SupplierRefunded(address supplierAddress, uint amount);
    
    event AuctionStarted(uint closingTime,uint startPrice);

    event AuctionClosed(uint closingTime, address clientAddress, address lowestBidder, uint lowestBid);
    
    event BidPlaced(address supplierAddress, address clientAddress, uint rate);
    
    event ConnectionEnded(address clientAddress, address supplierAddress);
    
    constructor () public{
        owner = msg.sender;
        totalBidders=0;
    }
    
    function addClient() payable public{
        require(!clients[msg.sender].exists,
        "Client already registered"
        );
        require(!fog_suppliers[msg.sender].exists,
        "Address registerd as a supplier"
        );
        clients[msg.sender]=(client(true,msg.value,false));
        emit ClientRegistered(msg.sender);
    }

    function addBidder(address supplier) onlyOwner public{
        require(!fog_suppliers[supplier].exists,
        "Fog node already joined the Auction"
        );
        require(!clients[supplier].exists,
        "Address registerd as a client"
        );
        fog_suppliers[supplier]=(fog(true,0,0));
        totalBidders++;
        emit BidderRegistered(supplier);
    }
    
    function abandonAuction() onlySupplier public{
        require(fog_suppliers[msg.sender].placed_bids==0,
        "Fog node has placed a pending bid"
        );
        refundSupplierDeposit();
        fog_suppliers[msg.sender]=(fog(false,0,0));
        totalBidders--;
        emit BidderAbandoned(msg.sender);
    }
    
    function refundSupplierDeposit() onlySupplier public{
        msg.sender.transfer(getSupplierDeposit());
        emit SupplierRefunded(msg.sender, getSupplierDeposit());
    }
    
    function getClientDeposit() public view onlyClient returns (uint){
        return clients[msg.sender].deposit;
    }
    
    function getSupplierDeposit() public view onlySupplier returns (uint){
        return fog_suppliers[msg.sender].deposit;
    }
    
    function startAuction(uint closingTime,uint startPrice, uint[] memory metrics) payable onlyClient public{
        require(!Auctions[msg.sender].open,
        "Auction already open"
        );
        require(closingTime>now,
        "Closing time cannot be in the past"
        );
        /*require(totalBidders>2,
        "More bidders required"
        );*/
        require(msg.value>=2*startPrice || getClientDeposit()>=2*startPrice,
        "Deposit Insufficient"
        );
        /*require(response_time + availability + capacity == 100,
        "Priority Vector Error"
        );*/
        clients[msg.sender].deposit=msg.value;
        Auctions[msg.sender]=bid(true,startPrice,address(0),now,closingTime,metrics);
        emit AuctionStarted(closingTime,startPrice);

    }

    function closeAuction() onlyClient public{
        require(Auctions[msg.sender].open,
        "Auction not available"
        );
        require(Auctions[msg.sender].closingTime<now,
        "Auction cannot be closed at this time"
        );
        require(Auctions[msg.sender].lowestBidder!=address(0),
        "No bids have been placed"
        );
        fog_suppliers[getLowestBidder(msg.sender)].placed_bids--;
        Auctions[msg.sender].open=false;
        getLowestBidder(msg.sender).transfer(getLowestBid(msg.sender));
        clients[msg.sender].deposit-=getLowestBid(msg.sender);
        emit AuctionClosed(now, msg.sender, getLowestBidder(msg.sender), getLowestBid(msg.sender));

    }
    
    function getLowestBidder(address buyer) public view returns (address payable){
        return Auctions[buyer].lowestBidder;
    }
    
    function getLowestBid(address buyer) public view returns (uint){
        return Auctions[buyer].lowestBid;
    }
    
    function contractBalance() public view returns(uint){
        return address(this).balance;
    }
    
    function placeBid(address buyer, uint rate) payable onlySupplier public{
        require(clients[buyer].exists,
        "Entered address does not refer to a client"
        );
        require(Auctions[buyer].open,
        "This Auction is not open for bidding"
        );
        require(rate<Auctions[buyer].lowestBid,
        "Please place a lower bid"
        );
        require(msg.value==rate,
        "Insufficient Deposit"
        );
        fog_suppliers[getLowestBidder(buyer)].deposit-=getLowestBid(buyer);
        fog_suppliers[getLowestBidder(buyer)].placed_bids--;
        if(getLowestBidder(buyer)!=address(0)){
            getLowestBidder(buyer).transfer(getLowestBid(buyer));
        }
        fog_suppliers[msg.sender].placed_bids++;
        fog_suppliers[msg.sender].deposit+=msg.value;
        Auctions[buyer].lowestBid=rate;
        Auctions[buyer].lowestBidder=msg.sender;
        emit BidPlaced(msg.sender, buyer, rate);
        
    }
    
    function endConnection() onlyClient public{
        require(Auctions[msg.sender].lowestBidder!=address(0),
        "No bids have been placed"
        );
        require(!Auctions[msg.sender].open,
        "Auction still open"
        );
        msg.sender.transfer(getClientDeposit());
        getLowestBidder(msg.sender).transfer(fog_suppliers[msg.sender].deposit);
        fog_suppliers[getLowestBidder(msg.sender)].deposit=0;
        clients[msg.sender].deposit=0;
        emit ConnectionEnded(msg.sender, getLowestBidder(msg.sender));
    }
}
