pragma solidity >=0.4.22 <0.6.0;
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
    }
    
    mapping (address => client) public clients;
    
    struct bid{
        bool open;
        uint lowestBid;
        address payable lowestBidder;
        uint startTime;
        uint closingTime;
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
        clients[msg.sender]=(client(true,msg.value));
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
    }
    
    function abandonAuction() onlySupplier public{
        require(fog_suppliers[msg.sender].placed_bids==0,
        "Fog node has placed a pending bid"
        );
        refundSupplierDeposit();
        fog_suppliers[msg.sender]=(fog(false,0,0));
        totalBidders--;
    }
    
    function refundSupplierDeposit() onlySupplier public{
        msg.sender.transfer(getSupplierDeposit());
    }
    
    function getClientDeposit() public view onlyClient returns (uint){
        return clients[msg.sender].deposit;
    }
    
    
    function getSupplierDeposit() public view onlySupplier returns (uint){
        return fog_suppliers[msg.sender].deposit;
    }
    
    function startAuction(uint closingTime,uint startPrice) payable onlyClient public{
        require(!Auctions[msg.sender].open,
        "Auction already open"
        );
        require(closingTime>now,
        "Closing time cannot be in the past"
        );
        /*require(totalBidders>2,
        "Insufficient number of bidders"
        );*/
        require(msg.value>=startPrice || getClientDeposit()>=startPrice,
        "Deposit Insufficient"
        );
        clients[msg.sender].deposit=msg.value;
        Auctions[msg.sender]=bid(true,startPrice,address(0),now,closingTime);

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
        clients[msg.sender].deposit=0;
        fog_suppliers[getLowestBidder(msg.sender)].deposit-=getLowestBid(msg.sender);
        msg.sender.transfer(getLowestBid(msg.sender));
        msg.sender.transfer(getClientDeposit());
        
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
        require(msg.value==2*rate,
        "Amount transferred Insufficient"
        );
        fog_suppliers[getLowestBidder(buyer)].deposit-=2*getLowestBid(buyer);
        fog_suppliers[getLowestBidder(buyer)].placed_bids--;
        if(getLowestBidder(buyer)!=address(0)){
            getLowestBidder(buyer).transfer(2*getLowestBid(buyer));
        }
        fog_suppliers[msg.sender].placed_bids++;
        fog_suppliers[msg.sender].deposit+=msg.value;
        Auctions[buyer].lowestBid=rate;
        Auctions[buyer].lowestBidder=msg.sender;
        
    }
    
    function endConnection() onlyClient public{
        msg.sender.transfer(getClientDeposit());
        getLowestBidder(msg.sender).transfer(getLowestBid(msg.sender));
    }
}
