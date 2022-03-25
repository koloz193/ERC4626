# SPDX-License-Identifier: MIT
# Cairo Implementation of ERC4626 based on https://github.com/fubuloubu/ERC4626
# ERC20 functionality taken from https://github.com/OpenZeppelin/cairo-contracts
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256, uint256_unsigned_div_rem, uint256_mul, uint256_eq, uint256_add, uint256_sub)
from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from openzeppelin.utils.constants import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from openzeppelin.token.erc20.library import (
    ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
    ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
    ERC20_transfer, ERC20_transferFrom, ERC20_mint, ERC20_burn, ERC20_allowances)
from starkware.cairo.common.math import assert_not_zero

# ERC4626 Events
@event
func Deposit(depositor : felt, receiver : felt, assets : Uint256, shares : Uint256):
end

@event
func Withdraw(withdrawer : felt, receiver : felt, owner : felt, assets : Uint256, shares : Uint256):
end

# ERC4626 Variables
@storage_var
func asset_address() -> (asset : felt):
end

# Constructor
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        name : felt, symbol : felt, decimals : felt, asset : felt):
    ERC20_initializer(name, symbol, decimals)
    return ()
end

# ERC20 Getters
@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC20_name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20_symbol()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalSupply : Uint256):
    let (totalSupply : Uint256) = ERC20_totalSupply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt):
    let (decimals) = ERC20_decimals()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (balance : Uint256):
    let (balance : Uint256) = ERC20_balanceOf(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (allowance : Uint256):
    let (allowance) = ERC20_allowance(owner, spender)
    return (allowance)
end

# ERC4626 Getters
@view
func asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (asset : felt):
    let (asset) = asset_address.read()
    return (asset)
end

@view
func totalAssets{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalAssets : Uint256):
    let (asset_addr) = asset_address.read()
    let (addr_this) = get_contract_address()
    let (totalAssets : Uint256) = IERC20.balanceOf(contract_address=asset_addr, account=addr_this)
    return (totalAssets)
end

@view
func convertToAssets{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        shareAmount : Uint256) -> (assetAmount : Uint256):
    let (assetAmount : Uint256) = _convert_to_assets(shareAmount)
    return (assetAmount)
end

@view
func convertToShares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        assetAmount : Uint256) -> (shareAmount : Uint256):
    let (shareAmount : Uint256) = _convert_to_assets(assetAmount)
    return (shareAmount)
end

@view
func maxDeposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        maxAmount : Uint256):
    alloc_locals
    local uint_max_high = 2 ** 128 - 1
    local uint_max_low = 2 ** 128
    let maxAmount = Uint256(low=uint_max_low, high=uint_max_high)
    return (maxAmount)
end

@view
func previewDeposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        assetAmount : Uint256) -> (shareAmount : Uint256):
    let (shareAmount) = _convert_to_shares(assetAmount)
    return (shareAmount)
end

@view
func maxMint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
        maxAmount : Uint256):
    alloc_locals
    local uint_max_high = 2 ** 128 - 1
    local uint_max_low = 2 ** 128
    let maxAmount = Uint256(low=uint_max_low, high=uint_max_high)
    return (maxAmount)
end

@view
func previewMint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        shareAmount : Uint256) -> (assetAmount : Uint256):
    alloc_locals
    let (assetAmount) = _convert_to_assets(shareAmount)
    let (res) = uint256_eq(assetAmount, Uint256(0, 0))
    if res == 0:
        return (shareAmount)
    end
    let (addr_this) = get_contract_address()
    let (asset_addr) = asset_address.read()
    let (balance : Uint256) = IERC20.balanceOf(contract_address=asset_addr, account=addr_this)
    let (res) = uint256_eq(balance, Uint256(0, 0))
    if res == 0:
        return (shareAmount)
    end
    return (assetAmount)
end

@view
func maxWithdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt) -> (maxAmount : Uint256):
    alloc_locals
    local uint_max_high = 2 ** 128 - 1
    local uint_max_low = 2 ** 128
    let maxAmount = Uint256(low=uint_max_low, high=uint_max_high)
    return (maxAmount)
end

@view
func previewWithdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        assetAmount : Uint256) -> (shareAmount : Uint256):
    alloc_locals
    let (shareAmount) = _convert_to_shares(assetAmount)
    let (res) = uint256_eq(shareAmount, Uint256(0, 0))
    if res == 0:
        return (Uint256(0, 0))
    end
    let (totalSupply : Uint256) = ERC20_totalSupply()
    let (res) = uint256_eq(totalSupply, Uint256(0, 0))
    if res == 0:
        return (Uint256(0, 0))
    end
    return (shareAmount)
end

@view
func maxRedeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
        maxAmount : Uint256):
    alloc_locals
    local uint_max_high = 2 ** 128 - 1
    local uint_max_low = 2 ** 128
    let maxAmount = Uint256(low=uint_max_low, high=uint_max_high)
    return (maxAmount)
end

@view
func previewRedeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        shareAmount : Uint256) -> (assetAmount : Uint256):
    alloc_locals
    let (assetAmount) = _convert_to_assets(shareAmount)
    return (assetAmount)
end

# ERC20 External Functions
@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        receiver : felt, amount : Uint256) -> (success : felt):
    ERC20_transfer(receiver, amount)
    return (TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, receiver : felt, amount : Uint256) -> (success : felt):
    ERC20_transferFrom(sender, receiver, amount)
    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256) -> (success : felt):
    ERC20_approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256) -> (success : felt):
    ERC20_increaseAllowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256) -> (success : felt):
    ERC20_decreaseAllowance(spender, subtracted_value)
    return (TRUE)
end

# ERC4626 External Functions
@external
func deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        assetAmount : Uint256, receiver : felt) -> (shareAmount : Uint256):
    alloc_locals
    let (shareAmount) = _convert_to_shares(assetAmount)
    let (caller) = get_caller_address()
    let (addr_this) = get_contract_address()
    ERC20_transferFrom(caller, addr_this, assetAmount)
    return (shareAmount)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        shareAmount : Uint256, receiver : felt) -> (assetAmount : Uint256):
    alloc_locals
    let (assetAmount) = previewMint(shareAmount)
    let (caller) = get_caller_address()
    let (addr_this) = get_contract_address()
    ERC20_transferFrom(caller, addr_this, assetAmount)
    let (oldTotalSupply) = ERC20_totalSupply()
    let (newTotalSupply : Uint256, _) = uint256_add(oldTotalSupply, shareAmount)
    ERC20_mint(receiver, shareAmount)
    Deposit.emit(depositor=caller, receiver=receiver, assets=assetAmount, shares=shareAmount)
    return (assetAmount)
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        assetAmount : Uint256, receiver : felt, owner : felt) -> (shareAmount : Uint256):
    alloc_locals
    let (shareAmount) = _convert_to_shares(assetAmount)
    let (res) = uint256_eq(shareAmount, Uint256(0, 0))
    let (caller) = get_caller_address()
    with_attr error_message("No Assets"):
        assert_not_zero(res)
    end
    let (totalSupply : Uint256) = ERC20_totalSupply()
    let (res) = uint256_eq(totalSupply, Uint256(0, 0))
    with_attr error_message("No Assets"):
        assert_not_zero(res)
    end
    ERC20_burn(owner, shareAmount)
    let (asset_addr) = asset_address.read()
    IERC20.transfer(contract_address=asset_addr, recipient=receiver, amount=assetAmount)
    Withdraw.emit(
        withdrawer=caller, receiver=receiver, owner=owner, assets=assetAmount, shares=shareAmount)
    return (shareAmount)
end

@external
func redeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        shareAmount : Uint256, receiver : felt, owner : felt) -> (assetAmount : Uint256):
    alloc_locals
    let (caller) = get_caller_address()
    let (assetAmount) = _convert_to_assets(shareAmount)
    let (asset_addr) = asset_address.read()
    let (allowance) = ERC20_allowances.read(owner=owner, spender=caller)
    local pedersen_ptr : HashBuiltin* = pedersen_ptr
    IERC20.transfer(contract_address=asset_addr, recipient=receiver, amount=assetAmount)
    Withdraw.emit(
        withdrawer=caller, receiver=receiver, owner=owner, assets=assetAmount, shares=shareAmount)
    let res = caller - owner
    if res != 0:
        let (newAllowance : Uint256) = uint256_sub(allowance, assetAmount)
        ERC20_allowances.write(owner=owner, spender=caller, value=newAllowance)
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    return (assetAmount)
end

# Internal Functions
func _convert_to_assets{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        shareAmount : Uint256) -> (assetAmount : Uint256):
    alloc_locals
    let (totalSupply : Uint256) = ERC20_totalSupply()
    let (res) = uint256_eq(totalSupply, Uint256(0, 0))
    if res == 0:
        return (assetAmount=Uint256(0, 0))
    end
    let (this_addr) = get_contract_address()
    let (balance : Uint256) = ERC20_balanceOf(this_addr)
    let (quot : Uint256, _) = uint256_mul(shareAmount, balance)
    let (assetAmount, _) = uint256_unsigned_div_rem(quot, totalSupply)
    return (assetAmount)
end

func _convert_to_shares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        assetAmount : Uint256) -> (shareAmount : Uint256):
    alloc_locals
    let (this_addr) = get_contract_address()
    let (totalSupply : Uint256) = ERC20_totalSupply()
    let (balance : Uint256) = ERC20_balanceOf(this_addr)
    let (res) = uint256_eq(totalSupply, Uint256(0, 0))
    if res == 0:
        return (balance)
    end
    let (res) = uint256_eq(balance, Uint256(0, 0))
    if res == 0:
        return (balance)
    end
    let (quot : Uint256, _) = uint256_mul(assetAmount, balance)
    let (assetAmount, _) = uint256_unsigned_div_rem(quot, totalSupply)
    return (assetAmount)
end
