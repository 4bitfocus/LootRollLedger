# LootRollLedger

Simple loot roll monitor and tracker for World of Warcraft.

This addon tracks item links sent to the raid/instance/party chat and then tracks rolls on that item. It uses the patented Luvly's Lovely Loot Rolling Method. This involves linking an item in raid chat followed by a number. The addon will give folks two minutes to do a `/roll <number>` if they want the item.

## The Basics

1. Only one person needs to run this addon
2. A player links an item in raid chat followed by a number
3. Use `/roll <number>` to roll on the item linked
4. After two minutes, the winner will be announced

## Improvement Opportunities

1. If the same item is linked by different players they will be tracked separately
2. Roll ties are not handled correctly and only one of the two ties will be announced
