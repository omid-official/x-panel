package job

import "x-panel/web/service"

type CheckXrayRunningJob struct {
	xrayService service.XrayService

	checkTime int
}

func NewCheckXrayRunningJob() *CheckXrayRunningJob {
	return new(CheckXrayRunningJob)
}

func (j *CheckXrayRunningJob) Run() {
	if j.xrayService.IsXrayRunning() {
		j.checkTime = 0
		return
	}
	j.checkTime++
	if j.checkTime < 2 {
		return
	}
	j.xrayService.SetToNeedRestart()
}
