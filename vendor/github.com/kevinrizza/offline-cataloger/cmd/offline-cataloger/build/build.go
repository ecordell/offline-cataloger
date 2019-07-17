// Copyright © 2019 The Offline-Cataloger Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package build

import (
	"fmt"

	"github.com/kevinrizza/offline-cataloger/pkg/apis"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

const (
	endpointArg       = "endpoint"
	namespaceArg      = "namespace"
	authTokenArg      = "auth-token"
	imageBuildArgsArg = "image-build-args"
	defaultEndpoint   = "https://quay.io/cnr"
)

func NewCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "build-image",
		Short: "Builds an operator-registry image for offline use",
		Long: `
Builds an operator-registry image that contains the operators defined
in the specified app registry. Publish it to local docker registry.
Requires docker runtime to execute.`,
		RunE: buildFunc,
	}

	cmd.Flags().StringP(authTokenArg, "a", "", "Authentication Token for App Registry endpoint")
	cmd.Flags().StringP(endpointArg, "e", "", "App Registry endpoint. Defaults to https://quay.io/cnr")
	cmd.Flags().StringP(namespaceArg, "n", "", "Namespace in App Registry")
	cmd.Flags().String(imageBuildArgsArg, "", "Extra image build arguments as one string such as \"--quiet --build-arg https_proxy=$https_proxy\"")

	return cmd
}

func buildFunc(cmd *cobra.Command, args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("command %s requires exactly one argument", cmd.CommandPath())
	}

	// Required Args
	image := args[0]

	namespace, _ := cmd.Flags().GetString(namespaceArg)
	if namespace == "" {
		return fmt.Errorf("Namespace not set!")
	}

	// Optional Args
	authToken, _ := cmd.Flags().GetString(authTokenArg)

	endpoint, _ := cmd.Flags().GetString(endpointArg)
	if endpoint == "" {
		endpoint = defaultEndpoint
	}

	imageBuildArgs, _ := cmd.Flags().GetString(imageBuildArgsArg)

	// Create the request to be handled by the builder
	request := &apis.BuildRequest{
		Image:              image,
		Namespace:          namespace,
		AuthorizationToken: authToken,
		Endpoint:           endpoint,
		ImageBuildArgs:     imageBuildArgs,
	}

	log.Infof("Building image %s", request.Image)

	buildHandler, err := apis.NewBuildHandler()
	if err != nil {
		return err
	}

	// Build
	err = buildHandler.Handle(request)
	if err != nil {
		return err
	}

	return nil
}
