export class ServerConfig {
  id: string = '';
  name: string = '';
  ip: string = '';
  port: number = 0;
  accelerationFactor: number = 1.0;

  constructor(id: string, name: string, ip: string, port: number, accelerationFactor?: number) {
    this.id = id;
    this.name = name;
    this.ip = ip;
    this.port = port;
    if (accelerationFactor !== undefined) {
      this.accelerationFactor = accelerationFactor;
    }
  }
}
