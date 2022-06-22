package main

import "fmt"

var tokenMap = func() map[string]string {
	return map[string]string{
		"flowTokenVault": "A.0ae53cb6e3f42a79.FlowToken",
		"fusdVault":      "A.f8d6e0586b0a20c7.FUSD",
		"emuTokenVault":  "A.f8d6e0586b0a20c7.EmuToken",
	}
}

func storagePathToTokenIdentifier(path string) string {
	return tokenMap()[path]
}

func float64ToUFix64String(x float64) string {
	return fmt.Sprintf("%.8f", x)
}
