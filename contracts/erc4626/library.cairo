# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_unsigned_div_rem, 
    uint256_mul, 
    uint256_eq, 
    uint256_add, 
    uint256_sub
)
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

from openzeppelin.token.erc20.library import (
    ERC20_name, 
    ERC20_symbol, 
    ERC20_totalSupply, 
    ERC20_decimals, 
    ERC20_balanceOf, 
    ERC20_allowance,
    ERC20_initializer, 
    ERC20_approve, 
    ERC20_increaseAllowance, 
    ERC20_decreaseAllowance,
    ERC20_transfer, 
    ERC20_transferFrom, 
    ERC20_mint, 
    ERC20_burn, 
    ERC20_allowances
)

#
# Events
#

@event
func Deposit(depositor : felt, receiver : felt, assets : Uint256, shares : Uint256):
end

@event
func Withdraw(withdrawer : felt, receiver : felt, owner : felt, assets : Uint256, shares : Uint256):
end

#
# Storage
#

@storage_var
func ERC4626_asset() -> (asset : felt):
end

namespace ERC4626:
    #
    # Constructor
    #
    func initialize{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            name : felt, 
            symbol : felt, 
            decimals : felt, 
            asset : felt
        ):
        ERC20_initializer(name, symbol, decimals)
        ERC4626_asset.write(value=asset)
        return ()
    end

    #
    # Functions
    #

    func name{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (name : felt):
        let (name) = ERC20_name()
        return (name)
    end

    func symbol{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (symbol : felt):
        let (symbol) = ERC20_symbol()
        return (symbol)
    end

    func totalSupply{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (total_supply : Uint256):
        let (total_supply) = ERC20_totalSupply()
        return (total_supply)
    end

    func decimals{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (decimals : felt):
        let (decimals) = ERC20_decimals()
        return (decimals)
    end

    func balanceOf{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(account : felt) -> (balance : Uint256):
        let (balance) = ERC20_balanceOf(account)
        return (balance)
    end

    func allowance{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(owner : felt, spender : felt) -> (allowance : Uint256):
        let (allowance) = ERC20_allowance(owner, spender)
        return (allowance)
    end

    func transfer{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(receiver : felt, amount : Uint256) -> (success : felt):
        ERC20_transfer(receiver, amount)
        return (TRUE)
    end

    func transferFrom{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            sender : felt, 
            receiver : felt, 
            amount : Uint256
        ) -> (success : felt):
        ERC20_transferFrom(sender, receiver, amount)
        return (TRUE)
    end

    func approve{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(spender : felt, amount : Uint256) -> (success : felt):
        ERC20_approve(spender, amount)
        return (TRUE)
    end

    func increaseAllowance{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(spender : felt, added_value : Uint256) -> (success : felt):
        ERC20_increaseAllowance(spender, added_value)
        return (TRUE)
    end

    func decreaseAllowance{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(spender : felt, subtracted_value : Uint256) -> (success : felt):
        ERC20_decreaseAllowance(spender, subtracted_value)
        return (TRUE)
    end

    func asset{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (asset : felt):
        let (asset) = ERC4626_asset.read()
        return (asset)
    end

    func totalAssets{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (total_assets : Uint256):
        let (asset_addr) = ERC4626_asset.read()
        let (addr_this) = get_contract_address()
        let (total_assets) = IERC20.balanceOf(asset_addr, addr_this)
        return (total_assets)
    end

    func convertToAssets{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(share_amount : Uint256) -> (asset_amount : Uint256):
        let (asset_amount) = _convert_to_assets(share_amount)
        return (asset_amount)
    end

    func convertToShares{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(asset_amount : Uint256) -> (share_amount : Uint256):
        let (share_amount) = _convert_to_assets(asset_amount)
        return (share_amount)
    end

    func maxDeposit{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }() -> (max_amount : Uint256):
        alloc_locals
        local uint_max_high = 2 ** 128 - 1
        local uint_max_low = 2 ** 128

        let max_amount = Uint256(uint_max_low, uint_max_high)
        return (max_amount)
    end

    func previewDeposit{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(asset_amount : Uint256) -> (share_amount : Uint256):
        let (share_amount) = _convert_to_shares(asset_amount)
        return (share_amount)
    end

    func maxMint{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(owner : felt) -> (max_amount : Uint256):
        alloc_locals
        local uint_max_high = 2 ** 128 - 1
        local uint_max_low = 2 ** 128

        let max_amount = Uint256(uint_max_low, uint_max_high)
        return (max_amount)
    end

    func previewMint{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(share_amount : Uint256) -> (asset_amount : Uint256):
        alloc_locals
        let (asset_amount) = _convert_to_assets(share_amount)
        let (res) = uint256_eq(asset_amount, Uint256(0, 0))

        if res == 0:
            return (share_amount)
        end

        let (addr_this) = get_contract_address()
        let (asset_addr) = ERC4626_asset.read()
        let (balance) = IERC20.balanceOf(asset_addr, addr_this)
        let (res) = uint256_eq(balance, Uint256(0, 0))

        if res == 0:
            return (share_amount)
        end

        return (asset_amount)
    end

    func maxWithdraw{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(owner : felt) -> (max_amount : Uint256):
        alloc_locals
        local uint_max_high = 2 ** 128 - 1
        local uint_max_low = 2 ** 128

        let maxAmount = Uint256(uint_max_low, uint_max_high)
        return (maxAmount)
    end

    func previewWithdraw{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(asset_amount : Uint256) -> (share_amount : Uint256):
        alloc_locals
        let (share_amount) = _convert_to_shares(asset_amount)
        let (res) = uint256_eq(share_amount, Uint256(0, 0))

        if res == 0:
            return (Uint256(0, 0))
        end

        let (total_supply) = ERC20_totalSupply()
        let (res) = uint256_eq(total_supply, Uint256(0, 0))

        if res == 0:
            return (Uint256(0, 0))
        end

        return (share_amount)
    end

    func maxRedeem{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(owner : felt) -> (max_amount : Uint256):
        alloc_locals
        local uint_max_high = 2 ** 128 - 1
        local uint_max_low = 2 ** 128

        let max_amount = Uint256(uint_max_low, uint_max_high)
        return (max_amount)
    end

    func previewRedeem{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(share_amount : Uint256) -> (asset_amount : Uint256):
        let (asset_amount) = _convert_to_assets(share_amount)
        return (asset_amount)
    end

    func deposit{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(asset_amount : Uint256, receiver : felt) -> (share_amount : Uint256):
        alloc_locals
        let (share_amount) = _convert_to_shares(asset_amount)
        let (caller) = get_caller_address()
        let (addr_this) = get_contract_address()

        ERC20_transferFrom(caller, addr_this, asset_amount)

        return (share_amount)
    end

    func mint{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(share_amount : Uint256, receiver : felt) -> (asset_amount : Uint256):
        alloc_locals
        let (asset_amount) = previewMint(share_amount)
        let (caller) = get_caller_address()
        let (addr_this) = get_contract_address()

        ERC20_transferFrom(caller, addr_this, asset_amount)
        ERC20_mint(receiver, share_amount)
        Deposit.emit(caller, receiver, asset_amount, share_amount)

        return (asset_amount)
    end

    func withdraw{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            asset_amount : Uint256, 
            receiver : felt, 
            owner : felt
        ) -> (share_amount : Uint256):
        alloc_locals
        let (share_amount) = _convert_to_shares(asset_amount)
        let (res) = uint256_eq(share_amount, Uint256(0, 0))
        let (caller) = get_caller_address()

        with_attr error_message("No Assets"):
            assert_not_zero(res)
        end

        let (total_supply) = ERC20_totalSupply()
        let (res) = uint256_eq(total_supply, Uint256(0, 0))

        with_attr error_message("No Assets"):
            assert_not_zero(res)
        end

        ERC20_burn(owner, share_amount)
        let (asset_addr) = ERC4626_asset.read()

        IERC20.transfer(asset_addr, receiver, asset_amount)
        Withdraw.emit(
            caller,
            receiver,
            owner,
            asset_amount,
            share_amount)

        return (share_amount)
    end

    func redeem{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            share_amount : Uint256, 
            receiver : felt, 
            owner : felt
        ) -> (asset_amount : Uint256):
        alloc_locals
        let (caller) = get_caller_address()
        let (asset_amount) = _convert_to_assets(share_amount)
        let (asset_addr) = ERC4626_asset.read()
        let (allowance) = ERC20_allowances.read(owner, caller)
        local pedersen_ptr : HashBuiltin* = pedersen_ptr

        IERC20.transfer(asset_addr, receiver, asset_amount)
        Withdraw.emit(
            caller,
            receiver,
            owner,
            asset_amount,
            share_amount)
        let res = caller - owner

        if res != 0:
            let (newAllowance) = uint256_sub(allowance, asset_amount)
            ERC20_allowances.write(owner, caller, newAllowance)
            tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end

        return (asset_amount)
    end
end

func _convert_to_assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(share_amount : Uint256) -> (assetAmount : Uint256):
    alloc_locals
    let (total_supply) = ERC20_totalSupply()
    let (res) = uint256_eq(total_supply, Uint256(0, 0))

    if res == 0:
        return (assetAmount=Uint256(0, 0))
    end

    let (this_addr) = get_contract_address()
    let (balance) = ERC20_balanceOf(this_addr)
    let (quot, _) = uint256_mul(share_amount, balance)
    let (asset_amount, _) = uint256_unsigned_div_rem(quot, total_supply)
    return (asset_amount)
end

func _convert_to_shares{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(asset_amount : Uint256) -> (share_amount : Uint256):
    alloc_locals
    let (this_addr) = get_contract_address()
    let (total_supply) = ERC20_totalSupply()
    let (balance) = ERC20_balanceOf(this_addr)
    let (res) = uint256_eq(total_supply, Uint256(0, 0))

    if res == 0:
        return (balance)
    end

    let (res) = uint256_eq(balance, Uint256(0, 0))

    if res == 0:
        return (balance)
    end

    let (quot, _) = uint256_mul(asset_amount, balance)
    let (share_amount, _) = uint256_unsigned_div_rem(quot, total_supply)
    return (share_amount)
end
