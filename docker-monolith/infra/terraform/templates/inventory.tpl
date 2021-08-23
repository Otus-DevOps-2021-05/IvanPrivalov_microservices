[docker_hosts]
%{ for ip in docker_hosts ~}
${ip}
%{ endfor ~}
