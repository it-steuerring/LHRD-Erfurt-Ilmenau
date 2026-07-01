//@description('Location for AVD host pool')
//param location string
@description('Name of the AVD host pool')
param hostPoolName string
@description('Friendly name for the host pool')
param hostPoolFriendlyName string
@description('Host pool type: Pooled or Personal')
param hostPoolType string = 'Pooled'
@description('Load balancer type: BreadthFirst or DepthFirst')
param loadBalancerType string
@description('Maximum session limit per session host')
param maxSessionLimit int = 16
@description('Expiration time for session host registration (ISO8601 string)')
param registrationInfoExpirationTime string
@description('Assignment type for personal desktops, one of Automatic or Direct')
param personalDesktopAssignmentType string
@description('Description of the host pool')
param hostPoolDescription string = 'AVDHostPool'
//param location string

//scaling plan params:
param scalingPlanName string
param rampUpStartTimeHour int 
param rampUpStartTimeMinute int 
param peakStartTimeHour int 
param peakStartTimeMinute int
param rampDownStartTimeHour int
param rampDownStartTimeMinute int
param rampDownMinimumHostsPct int
param rampDownCapacityThresholdPct int
param rampDownforceLogoffUsers bool
param rampDownWaitTimeMinutes int
param rampDownStopHostsWhen string
param offPeakStartTimeHour int
param scalingPlanEnabled bool
param rampUpMinimumHostsPct int
param rampUpCapacityThresholdPct int
param scheduleDaysOfWeek array
param scheduleName string
param offPeakStartTimeMinute int

@description('Name des AVD-Workspaces')
param avdworkspaceName string

@description('Friendly Name für den Workspace')
param workspaceFriendlyName string = 'AVD Workspace'

@description('Name der Desktop-App-Gruppe')
param avdappGroupName string

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: 'westeurope'
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    maxSessionLimit: maxSessionLimit
    description: hostPoolDescription
    friendlyName: hostPoolFriendlyName
    preferredAppGroupType: personalDesktopAssignmentType
    startVMOnConnect: true
    registrationInfo: {
      expirationTime: registrationInfoExpirationTime
      registrationTokenOperation: 'Update'
    }
    customRdpProperty: 'drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;use multimon:i:0;encode redirected video capture:i:1;camerastoredirect:s:*;audiocapturemode:i:1;screen mode id:i:2;redirectwebauthn:i:1'
  }
}

// AppGroup create

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: avdappGroupName
  location: 'westeurope'
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
  }
}

// Workspace create
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-03-01-preview' = {
  name: avdworkspaceName
  location: 'westeurope'
  properties: {
    friendlyName: workspaceFriendlyName
    description: 'Arbeitsbereich für Azure Virtual Desktop'
    applicationGroupReferences: [
      appGroup.id
    ]
    publicNetworkAccess: 'Enabled'
  }
}

resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2025-10-10' = {
  name: scalingPlanName
  location: 'westeurope'
  properties: {
    timeZone: 'W. Europe Standard Time'
    hostPoolType: hostPoolType
    hostPoolReferences: [
      {
        hostPoolArmPath: hostPool.id
        scalingPlanEnabled: scalingPlanEnabled
      }
    ]
      schedules: [
      {
        name: scheduleName
        daysOfWeek: scheduleDaysOfWeek
        rampUpStartTime: {
          hour: rampUpStartTimeHour
          minute: rampUpStartTimeMinute
        }
        rampUpLoadBalancingAlgorithm: loadBalancerType
        rampUpMinimumHostsPct: rampUpMinimumHostsPct
        rampUpCapacityThresholdPct: rampUpCapacityThresholdPct

        peakStartTime: {
          hour: peakStartTimeHour
          minute: peakStartTimeMinute
        }
        peakLoadBalancingAlgorithm: loadBalancerType

        rampDownStartTime: {
          hour: rampDownStartTimeHour
          minute: rampDownStartTimeMinute
        }
        rampDownLoadBalancingAlgorithm: loadBalancerType
        rampDownMinimumHostsPct: rampDownMinimumHostsPct
        rampDownCapacityThresholdPct: rampDownCapacityThresholdPct
        rampDownForceLogoffUsers: rampDownforceLogoffUsers
        rampDownWaitTimeMinutes: rampDownWaitTimeMinutes
        rampDownStopHostsWhen: rampDownStopHostsWhen

        offPeakStartTime: {
          hour: offPeakStartTimeHour
          minute: offPeakStartTimeMinute
        }
        offPeakLoadBalancingAlgorithm: loadBalancerType
      }
    ]
  }
}

output workspaceId string = workspace.id
output hostPoolId string = hostPool.id
output registrationToken string = first(hostPool.listRegistrationTokens().value).token
output registrationInfoToken string = first(hostPool.listRegistrationTokens().value).token
