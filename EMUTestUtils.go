package main

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/bjartek/overflow/overflow"
	"github.com/stretchr/testify/assert"
)

type OverflowTestUtils struct {
	T *testing.T
	O *overflow.Overflow
}

func (otu *OverflowTestUtils) setupFUSDVaultWithBalance(o *overflow.Overflow, account string, amount float64) *OverflowTestUtils {
	otu.O.TransactionFromFile("FUSD/setup").SignProposeAndPayAs(account).RunPrintEventsFull()
	otu.O.TransactionFromFile("demo/mintFUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(amount).Address(account)).RunPrintEventsFull()
	return otu
}

func (otu *OverflowTestUtils) createPoolFlowFUSD(o *overflow.Overflow, account string, flowAmount float64, fusdAmount float64) *OverflowTestUtils {
	otu.O.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(flowAmount).
			UFix64(fusdAmount)).
		Test(otu.T).AssertSuccess()
	return otu
}

func (otu *OverflowTestUtils) getPoolMeta() *OverflowTestUtils {
	otu.O.ScriptFromFile("get_pool_meta")
	return otu
}

func (otu *OverflowTestUtils) tickClock(time float64) *OverflowTestUtils {
	otu.O.TransactionFromFile("clock").SignProposeAndPayAs("find").
		Args(otu.O.Arguments().
			UFix64(time)).
		Test(otu.T).AssertSuccess()
	return otu
}

func (out *OverflowTestUtils) currentTime() float64 {
	value, err := out.O.Script(`import Clock from "../contracts/Clock.cdc"
pub fun main() :  UFix64 {
    return Clock.time()
}`).RunReturns()
	assert.NoErrorf(out.T, err, "Could not execute script")
	currentTime := value.String()
	res, err := strconv.ParseFloat(currentTime, 64)
	assert.NoErrorf(out.T, err, "Could not parse as float")
	return res
}

func (otu *OverflowTestUtils) accountAddress(name string) string {
	return fmt.Sprintf("0x%s", otu.O.Account(name).Address().String())
}
