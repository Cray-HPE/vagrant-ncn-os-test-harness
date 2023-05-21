// # MIT License
// #
// # (C) Copyright 2023 Hewlett Packard Enterprise Development LP
// #
// # Permission is hereby granted, free of charge, to any person obtaining a
// # copy of this software and associated documentation files (the "Software"),
// # to deal in the Software without restriction, including without limitation
// # the rights to use, copy, modify, merge, publish, distribute, sublicense,
// # and/or sell copies of the Software, and to permit persons to whom the
// # Software is furnished to do so, subject to the following conditions:
// #
// # The above copyright notice and this permission notice shall be included
// # in all copies or substantial portions of the Software.
// #
// # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// # THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// # OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// # ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// # OTHER DEALINGS IN THE SOFTWARE.
// #
package main

import (
	"context"
	"fmt"
	"github.com/spf13/viper"
	"strings"

	"github.com/google/go-github/github"
	"github.com/manifoldco/promptui"
)

func main() {
	initConfig()
	substringToMatch := PromptForVersionSubstring()
	result := SelectCSMTagsWithString(substringToMatch)
	fmt.Printf("You chose %q\n", result)
	updateVersionInEnvFile(result)
}

func initConfig() {
	viper.SetConfigType("env")
	viper.SetConfigFile("../../.env")
	err := viper.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("Fatal error config file %w", err))
	}
}

func PromptForVersionSubstring() string {
	searchPrompt := promptui.Prompt{
		Label:   "Type a portion of the version to match, e.g. 1.4.0 or 1.5.0-alpha",
		Default: "",
	}
	substringToMatch, err := searchPrompt.Run()
	if err != nil {
		panic(fmt.Errorf("Prompt failed #{err}\n"))
	}
	return substringToMatch
}

func SelectCSMTagsWithString(substringToMatch string) string {
	prompt := promptui.Select{
		Label: "Choose CSM Tag",
		Items: GetCSMVersions(substringToMatch),
		Size:  15,
	}
	_, result, err := prompt.Run()
	if err != nil {
		panic(fmt.Errorf("Prompt failed %q\n", err))
	}
	return result
}

func GetCSMVersions(substringToMatch string) []string {
	client := github.NewClient(nil)
	opts := &github.ListOptions{PerPage: 999}
	tags, _, err := client.Repositories.ListTags(context.Background(), "Cray-HPE", "csm", opts)
	if err != nil {
		panic(fmt.Errorf("Failed to lookup tags #{err}\n"))
	}
	if len(tags) == 0 {
		panic(fmt.Errorf("No tags were found. Check your connection to Github.com"))
	}
	filteredTags := filterTagsByString(tags, substringToMatch)
	if len(filteredTags) == 0 {
		panic(fmt.Errorf("No results with #{substringToMatch} were found."))
	}
	return filteredTags
}

func filterTagsByString(tags []*github.RepositoryTag, substringToMatch string) []string {
	var filteredTags []string
	for _, tag := range tags {
		name := tag.GetName()
		if strings.Contains(name, substringToMatch) {
			filteredTags = append(filteredTags, name)
		}
	}
	return filteredTags
}

func updateVersionInEnvFile(tag string) {
	viper.Set("CSM_TAG", tag)
	err := viper.WriteConfig()
	if err != nil {
		panic(fmt.Errorf("Error while updating config. #{err}"))
	}
}
