package job

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	ss "strings"
	"x-panel/database"
	"x-panel/database/model"
	"x-panel/logger"
	"x-panel/web/service"
)

var job *CheckClientIpJob

type CheckClientIpJob struct {
	xrayService    service.XrayService
	inboundService service.InboundService
}

func NewIpCheckJob() *CheckClientIpJob {
	job = new(CheckClientIpJob)
	return job
}

func (j *CheckClientIpJob) Run() {
	logger.Debug("Check Client Ip Job...")
	ProcessAccessFile()

}

func ProcessAccessFile() {
	accessFilePath := GetAccessFilePath()
	if accessFilePath == "" {
		logger.Warning("Xray log not init in config.json")
		return
	}

	data, err := os.ReadFile(accessFilePath)
	InboundIp := make(map[string]string)
	checkError(err)

	// clean log
	if err := os.Truncate(GetAccessFilePath(), 0); err != nil {
		checkError(err)
	}

	lines := ss.Split(string(data), "\n")
	for _, line := range lines {
		IpRegx, _ := regexp.Compile(`[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+`)
		EmailRegx, _ := regexp.Compile(`email:.+`)

		matchesIp := IpRegx.FindString(line)
		matchesEmail := EmailRegx.FindString(line)
		if len(matchesIp) > 0 {
			ip := matchesIp

			if ip == "127.0.0.1" || ip == "1.1.1.1" || ip == "0.0.0.0" {
				continue
			}
			if matchesEmail == "" {
				continue
			}

			matchesEmail = ss.Split(matchesEmail, "email: ")[1]
			InboundIp[matchesEmail] = ip
		}

	}

	for clientEmail, Ip := range InboundIp {
		inboundClientIp, _ := GetInbounds(clientEmail)
		Isp, err := GetIspByIp(Ip)
		if err != nil {
			logger.Warning("Something went wrong to get Isp:", err)
		}

		err = UpdateInbounds(inboundClientIp, Ip, Isp)
		if err != nil {
			logger.Warning("Something went wrong on save data to database")
		}

	}

}
func GetAccessFilePath() string {

	config, err := os.ReadFile("bin/config.json")
	checkError(err)

	jsonConfig := map[string]interface{}{}
	err = json.Unmarshal(config, &jsonConfig)
	checkError(err)
	if jsonConfig["log"] != nil {
		jsonLog := jsonConfig["log"].(map[string]interface{})
		if jsonLog["access"] != nil {

			accessLogPath := jsonLog["access"].(string)

			return accessLogPath
		}
	}
	return ""

}
func checkError(e error) {
	if e != nil {
		logger.Warning("client ip job err:", e)
	}
}

func GetInbounds(clientEmail string) (*model.Inbound, error) {
	db := database.GetDB()
	Inbounds := &model.Inbound{}
	err := db.Model(model.Inbound{}).Where("Email = ?", clientEmail).First(Inbounds).Error
	if err != nil {
		return nil, err
	}
	return Inbounds, nil
}

func UpdateInbounds(inboundClientIp *model.Inbound, Ip string, Isp string) error {
	inboundClientIp.Ip = Ip
	inboundClientIp.Isp = Isp
	db := database.GetDB()
	err := db.Save(inboundClientIp).Error
	if err != nil {
		return err
	}
	return nil
}
func GetIspByIp(Ip string) (Isp string, Error error) {
	type ResponseStruct struct {
		Org string `json:"org"`
	}

	Url := fmt.Sprintf("http://ip-api.com/json/%v", Ip)
	Response, err := http.Get(Url)
	if err != nil {
		return "", errors.New("failed to connect to ip-api.com")
	}
	defer Response.Body.Close()
	Body, err := io.ReadAll(Response.Body)
	if err != nil {
		return "", errors.New("failed to read body")
	}
	var responseStruct ResponseStruct
	err = json.Unmarshal(Body, &responseStruct)
	if err != nil {
		return "", errors.New("failed to Unmarshal Body")
	}

	return responseStruct.Org, nil
}
