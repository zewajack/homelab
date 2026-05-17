```bash
root@lap-k8s-master-01:~# kubectl describe pod -n metallb-system speaker-h2rlw

Events:
  Type     Reason       Age                From               Message
  ----     ------       ----               ----               -------
  Normal   Scheduled    98s                default-scheduler  Successfully assigned metallb-system/speaker-h2rlw to lap-k8s-master-01.b13homelab.in
  Warning  FailedMount  34s (x8 over 98s)  kubelet            MountVolume.SetUp failed for volume "memberlist" : secret "memberlist" not found
```
1️⃣ Create the memberlist secret manually

```bash
kubectl create secret generic -n metallb-system memberlist \
  --from-literal=secretkey="$(openssl rand -base64 128)"

2️⃣ Restart the speaker pods
They will restart automatically because it’s a DaemonSet, but to be sure:
```bash
kubectl -n metallb-system rollout restart ds speaker

kubectl get pods -n metallb-system
```
3️⃣ If Controller is not running then,
```bash
kubectl -n metallb-system rollout restart deployment controller
```
