# DDD basics

## Domain
Let's say we are working on e-commerce. We will build a very simple shopping application. Guests are entering our site, adding some stuff to persistent cart and ordering it after they are finished. Order should shipped after cart checkout.
### Events
* SiteOpened
  At this moment a wild guest appears.
* ItemAddedToCart
  Something nice and shiny was added to guests cart
* CartCheckedOut
  Guest is finished, we have to ship stuff!
* OrderShipped
  Our great shipping subsystem told us order was posted via Poczta Polska.

### Option A) RESTful (HTTP) + Events
* POST /guest/:id
  Creates new guest -> SiteOpened
* GET /items

### Option B) (CQRS+HTTP) + Events
#### Commands
* OpenSite -> SiteOpened := POST /command/open_site
  Issued by the browser when guest has said "Mellon" and entered.
* AddItem -> ItemAddedToCart := POST /command/add_item
  Issued by our greatest Application to date when customer wants something in cart
* CheckoutCart -> CartCheckedOut := POST /command/checkout_cart
  Again, application tells us to ship.
* AddItemForSale -> ItemAddedForSale
  Creates item for sale
#### Queries
* GuestCart := GET /query/guest_cart/:guest_id
  Shows what we currently have in Cart
* Items := GET /query/items
  Everything we have in our shop at hand
* Orders := GET /query/orders/:guest_id
  Shows state of all orders for given customer

### Option C) CQRS + Events + Websocket
e.g.
* Command OpenSite := 'open_site' client event
* Query Items := 'get_items' client event + server response

### Option D) CQRS + Events + RESTful
e.g.
* POST /guest/:id/cart/item/:id => AddItem
