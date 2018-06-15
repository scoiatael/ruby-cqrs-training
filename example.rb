require 'pry'
require_relative 'lib'

dispatch!(command: :AddItemForSale, params: { name: 'Gameboy' })
dispatch!(command: :AddItemForSale, params: { name: 'AA Battery' })
dispatch!(command: :AddItemForSale, params: { name: 'Toothbrush' })
dispatch!(command: :OpenSite, params: { guest_id: 'Foobert' })
puts "---- Query: Items"
puts query(query: :Items, params: {})
puts "---- Query: GuestCart"
puts query(query: :GuestCart, params: { guest_id: 'Foobert' })
dispatch!(command: :AddItem, params: { item_id: 'Gameboy', guest_id: 'Foobert' })
dispatch!(command: :AddItem, params: { item_id: 'AA Battery', guest_id: 'Foobert' })
dispatch!(command: :AddItem, params: { item_id: 'AA Battery', guest_id: 'Foobert' })
dispatch!(command: :CheckoutCart, params: { guest_id: 'Foobert' })
