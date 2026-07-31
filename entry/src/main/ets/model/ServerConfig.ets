export class ServerConfig {
  id: string = '';
  name: string = '';
  ip: string = '';
  port: number = 0;

  constructor(id: string, name: string, ip: string, port: number) {
    this.id = id;
    this.name = name;
    this.ip = ip;
    this.port = port;
  }
}
